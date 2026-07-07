import { requireRole } from "@/lib/auth";
import { AppShell } from "@/components/domain/app-shell";

// Staff surface (§7): coordinators, managers, org admins. Role gating here is
// defense-in-depth on top of Pundit (spec §10) — inspectors/agency users are
// redirected to their own home.
export default async function StaffLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireRole("org_admin", "coordinator", "manager");

  return (
    <AppShell user={user} surface="staff">
      {children}
    </AppShell>
  );
}
