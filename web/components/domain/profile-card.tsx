import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import type { Role, User } from "@/lib/types";

const ROLE_LABEL: Record<Role, string> = {
  org_admin: "Org admin",
  coordinator: "Coordinator",
  manager: "Inspection manager",
  inspector: "Inspector",
};

// Read-only profile summary. Editing name/password is a follow-up; this gives
// every role a populated Profile tab today.
export function ProfileCard({ user }: { user: User }) {
  const rows: [string, string | null][] = [
    ["Name", user.name],
    ["Email", user.email],
    ["Role", ROLE_LABEL[user.role]],
    ["License #", user.license_number],
    ["Office", user.office?.name ?? null],
    ["Organization", user.organization?.name ?? null],
  ];

  return (
    <Card className="max-w-xl">
      <CardContent>
        <dl className="flex flex-col">
          {rows.map(([label, value], i) => (
            <div
              key={label}
              className={
                "grid grid-cols-[140px_1fr] gap-3 py-3 " +
                (i < rows.length - 1 ? "border-b border-border" : "")
              }
            >
              <dt className="text-body text-muted-foreground">{label}</dt>
              <dd className="text-body font-medium text-foreground">
                {value ?? <span className="text-muted-foreground">—</span>}
              </dd>
            </div>
          ))}
        </dl>
        <div className="mt-4">
          <Badge variant="muted">
            To change your name or password, contact your org admin (self-service editing
            is coming soon).
          </Badge>
        </div>
      </CardContent>
    </Card>
  );
}
