"use client";

import * as React from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { InfoHint } from "@/components/ui/info-hint";
import { apiFetch, ApiError } from "@/lib/api";
import type { Role, User } from "@/lib/types";

const ROLES: { value: Role; label: string }[] = [
  { value: "org_admin", label: "Org admin" },
  { value: "coordinator", label: "Coordinator" },
  { value: "manager", label: "Inspection manager" },
  { value: "inspector", label: "Inspector" },
];

export function UsersPermissionsTable({
  initialMembers,
  currentUserId,
}: {
  initialMembers: User[];
  currentUserId: string;
}) {
  const [members, setMembers] = React.useState<User[]>(initialMembers);
  const [busyId, setBusyId] = React.useState<string | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  async function patch(id: string, body: Record<string, unknown>) {
    setBusyId(id);
    setError(null);
    try {
      const updated = await apiFetch<User>(`/api/v1/users/${id}`, {
        method: "PATCH",
        body: JSON.stringify({ user: body }),
      });
      setMembers((prev) => prev.map((m) => (m.id === id ? { ...m, ...updated } : m)));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Update failed.");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-1.5">
        <h3 className="text-title text-foreground">Members</h3>
        <InfoHint label="About permissions">
          Change a member's role or deactivate their access. You can't change your own
          role or status. Invite new members from the Team screen.
        </InfoHint>
      </div>

      {error && (
        <p role="alert" className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-label text-destructive">
          {error}
        </p>
      )}

      <div className="overflow-x-auto rounded-lg border border-border">
        <table className="w-full text-body" aria-label="Team permissions">
          <thead>
            <tr className="border-b border-border bg-muted/40">
              <th className="px-4 py-3 text-left font-medium text-muted-foreground">Name</th>
              <th className="px-4 py-3 text-left font-medium text-muted-foreground">Role</th>
              <th className="px-4 py-3 text-left font-medium text-muted-foreground">Status</th>
              <th className="px-4 py-3 text-right font-medium text-muted-foreground">Actions</th>
            </tr>
          </thead>
          <tbody>
            {members.map((m, i) => {
              const self = m.id === currentUserId;
              return (
                <tr
                  key={m.id}
                  className={i < members.length - 1 ? "border-b border-border" : ""}
                >
                  <td className="px-4 py-3">
                    <div className="font-medium text-foreground">
                      {m.name}
                      {self && <span className="ml-2 text-label text-muted-foreground">(you)</span>}
                    </div>
                    <div className="text-label text-muted-foreground">{m.email}</div>
                  </td>
                  <td className="px-4 py-3">
                    <select
                      className="h-8 rounded-md border border-input bg-transparent px-2 text-label disabled:opacity-50"
                      value={m.role}
                      disabled={self || busyId === m.id}
                      onChange={(e) => patch(m.id, { role: e.target.value })}
                      aria-label={`Role for ${m.name}`}
                    >
                      {ROLES.map((r) => (
                        <option key={r.value} value={r.value}>
                          {r.label}
                        </option>
                      ))}
                    </select>
                  </td>
                  <td className="px-4 py-3">
                    {m.pending_invitation ? (
                      <Badge variant="secondary">Pending invite</Badge>
                    ) : m.active ? (
                      <Badge variant="default">Active</Badge>
                    ) : (
                      <Badge variant="muted">Deactivated</Badge>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {!self && (
                      <Button
                        size="sm"
                        variant="outline"
                        disabled={busyId === m.id}
                        onClick={() => patch(m.id, { active: !m.active })}
                      >
                        {m.active ? "Deactivate" : "Reactivate"}
                      </Button>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
