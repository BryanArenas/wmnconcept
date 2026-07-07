import { requireRole } from "@/lib/auth";
import { AppShell } from "@/components/domain/app-shell";

// Field surface (§7): inspectors only. Phone-first single column; the AppShell
// drops the sidebar for this surface.
export default async function FieldLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireRole("inspector");

  return (
    <AppShell user={user} surface="field">
      {children}
    </AppShell>
  );
}
