import { requireUser, surfaceForRole } from "@/lib/auth";
import { AppShell } from "@/components/domain/app-shell";

// Settings lives outside the (staff)/(field) route groups because it serves
// both surfaces: an admin edits the company, an inspector edits availability.
// The shell picks the right chrome from the signed-in user's role.
export default async function SettingsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireUser();

  return (
    <AppShell user={user} surface={surfaceForRole(user.role)}>
      {children}
    </AppShell>
  );
}
