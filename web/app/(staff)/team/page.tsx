import { cookies } from "next/headers";
import { PageHeader } from "@/components/domain/page-header";
import { TeamTable } from "@/components/domain/team-table";
import { requireRole } from "@/lib/auth";
import { apiFetch } from "@/lib/api";
import type { Role, User, Paginated } from "@/lib/types";

// Staff roster + provisioning. org_admin and coordinators can invite; the roles
// they may hand out differ (coordinators: inspectors only) and are passed to the
// dialog. Includes pending (unconfirmed) invites via ?status=all.
export default async function TeamPage() {
  const user = await requireRole("org_admin", "coordinator", "manager");
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();

  const result = await apiFetch<Paginated<User>>("/api/v1/users?status=all", {
    headers: { cookie: cookieHeader },
    cache: "no-store",
  }).catch(() => ({ data: [] as User[], meta: { next_cursor: null } }));

  const allowedRoles: Role[] =
    user.role === "org_admin"
      ? ["inspector", "coordinator", "manager", "org_admin"]
      : user.role === "coordinator"
        ? ["inspector"]
        : [];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Organization"
        title="Team"
        description="Invite inspectors and staff to your organization."
      />
      <TeamTable initialMembers={result.data} allowedRoles={allowedRoles} />
    </div>
  );
}
