import { requireUser } from "@/lib/auth";
import { AppShell } from "@/components/domain/app-shell";

// Agency portal (§7) — the partner wedge. Agency users authenticate against the
// separate agency_users table, which lands in M2; until then this surface is
// scaffolded and only requires a signed-in identity. Namespaced under /agency/*
// (see docs/decisions/0001-agency-surface-url-namespace.md).
export default async function AgencyLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireUser();

  return (
    <AppShell user={user} surface="agency">
      {children}
    </AppShell>
  );
}
