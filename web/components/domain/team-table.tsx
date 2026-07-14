"use client";

import * as React from "react";
import { Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { AddMemberDialog } from "@/components/domain/add-member-dialog";
import type { Role, User } from "@/lib/types";

const ROLE_LABEL: Record<Role, string> = {
  org_admin: "Org admin",
  coordinator: "Coordinator",
  manager: "Inspection manager",
  inspector: "Inspector",
};

interface Props {
  initialMembers: User[];
  allowedRoles: Role[];
}

export function TeamTable({ initialMembers, allowedRoles }: Props) {
  const [members, setMembers] = React.useState<User[]>(initialMembers);
  const canCreate = allowedRoles.length > 0;

  function handleCreated(user: User) {
    setMembers((prev) => {
      if (prev.some((m) => m.id === user.id)) return prev;
      return [user, ...prev];
    });
  }

  return (
    <div className="flex flex-col gap-4">
      {canCreate && (
        <div className="flex justify-end">
          <AddMemberDialog allowedRoles={allowedRoles} onCreated={handleCreated} />
        </div>
      )}

      {members.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-border py-16 text-center">
          <Users className="h-8 w-8 text-muted-foreground/40" />
          <div>
            <p className="text-body font-medium text-foreground">No team members yet</p>
            <p className="mt-1 text-body text-muted-foreground">
              Invite inspectors and staff to get started.
            </p>
          </div>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-border">
          <table className="w-full text-body" aria-label="Team members">
            <thead>
              <tr className="border-b border-border bg-muted/40">
                <th className="px-4 py-3 text-left font-medium text-muted-foreground">Name</th>
                <th className="px-4 py-3 text-left font-medium text-muted-foreground">Email</th>
                <th className="px-4 py-3 text-left font-medium text-muted-foreground">Role</th>
                <th className="px-4 py-3 text-left font-medium text-muted-foreground">Status</th>
              </tr>
            </thead>
            <tbody>
              {members.map((m, i) => (
                <tr
                  key={m.id}
                  className={
                    i < members.length - 1
                      ? "border-b border-border transition-colors hover:bg-muted/30"
                      : "transition-colors hover:bg-muted/30"
                  }
                >
                  <td className="px-4 py-3 font-medium text-foreground">
                    {m.name}
                    {m.license_number && (
                      <span className="ml-2 text-label text-muted-foreground">
                        {m.license_number}
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-muted-foreground">{m.email}</td>
                  <td className="px-4 py-3">
                    <Badge variant="muted">{ROLE_LABEL[m.role] ?? m.role}</Badge>
                  </td>
                  <td className="px-4 py-3">
                    {m.pending_invitation ? (
                      <Badge variant="secondary">Pending invite</Badge>
                    ) : (
                      <Badge variant="default">Active</Badge>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
