import { cookies } from "next/headers";
import { requireUser } from "@/lib/auth";
import { apiFetch } from "@/lib/api";
import { PageHeader } from "@/components/domain/page-header";
import { SettingsView } from "./settings-view";
import type { Organization, User } from "@/lib/types";

// Role-aware settings. Admins get company + team/permissions; inspectors get
// availability; everyone gets a profile view. Admin data is fetched here so the
// first paint is populated; inspector availability loads client-side.
export default async function SettingsPage() {
  const user = await requireUser();
  const cookieStore = await cookies();
  const opts = { headers: { cookie: cookieStore.toString() }, cache: "no-store" as const };

  let organization: Organization | null = null;
  let members: User[] = [];

  if (user.role === "org_admin") {
    const [orgRes, usersRes] = await Promise.all([
      apiFetch<{ data: Organization }>("/api/v1/organization", opts).catch(() => null),
      apiFetch<{ data: User[] }>("/api/v1/users?status=all", opts).catch(() => null),
    ]);
    organization = orgRes?.data ?? user.organization;
    members = usersRes?.data ?? [];
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Account"
        title="Settings"
        description="Manage your account and, if you're an admin, your company and team."
      />
      <SettingsView user={user} initialOrganization={organization} initialMembers={members} />
    </div>
  );
}
