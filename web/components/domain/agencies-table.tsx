"use client";

import * as React from "react";
import { Building2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { AddAgencyDialog } from "@/components/domain/add-agency-dialog";
import type { Agency } from "@/lib/types";

const TYPE_LABEL: Record<string, string> = {
  insurance: "Insurance",
  real_estate: "Real estate",
  other: "Other",
};

const BILLING_LABEL: Record<string, string> = {
  fixed_rate: "Fixed rate",
  commission: "Commission",
};

interface Props {
  initialAgencies: Agency[];
  canCreate: boolean;
}

export function AgenciesTable({ initialAgencies, canCreate }: Props) {
  const [agencies, setAgencies] = React.useState<Agency[]>(initialAgencies);

  function handleCreated(agency: Agency) {
    setAgencies((prev) => [agency, ...prev]);
  }

  return (
    <div className="flex flex-col gap-4">
      {canCreate && (
        <div className="flex justify-end">
          <AddAgencyDialog onCreated={handleCreated} />
        </div>
      )}

      {agencies.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-border py-16 text-center">
          <Building2 className="h-8 w-8 text-muted-foreground/40" />
          <div>
            <p className="text-body font-medium text-foreground">No agencies yet</p>
            <p className="mt-1 text-body text-muted-foreground">
              Onboard a referral partner to get started.
            </p>
          </div>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-border">
          <table className="w-full text-body" aria-label="Agencies">
            <thead>
              <tr className="border-b border-border bg-muted/40">
                <th className="px-4 py-3 text-left font-medium text-muted-foreground">
                  Agency
                </th>
                <th className="px-4 py-3 text-left font-medium text-muted-foreground">
                  Type
                </th>
                <th className="px-4 py-3 text-left font-medium text-muted-foreground">
                  Billing
                </th>
                <th className="px-4 py-3 text-left font-medium text-muted-foreground">
                  Contact email
                </th>
              </tr>
            </thead>
            <tbody>
              {agencies.map((agency, i) => (
                <tr
                  key={agency.id}
                  className={
                    i < agencies.length - 1
                      ? "border-b border-border hover:bg-muted/30 transition-colors"
                      : "hover:bg-muted/30 transition-colors"
                  }
                >
                  <td className="px-4 py-3 font-medium text-foreground">
                    {agency.name}
                  </td>
                  <td className="px-4 py-3">
                    <Badge variant="muted">
                      {TYPE_LABEL[agency.type] ?? agency.type}
                    </Badge>
                  </td>
                  <td className="px-4 py-3">
                    <Badge
                      variant={
                        agency.billing_mode === "commission" ? "default" : "secondary"
                      }
                    >
                      {BILLING_LABEL[agency.billing_mode] ?? agency.billing_mode}
                      {agency.billing_mode === "commission" &&
                        agency.commission_rate && (
                          <span className="ml-1 opacity-70">
                            {(parseFloat(agency.commission_rate) * 100).toFixed(0)}%
                          </span>
                        )}
                    </Badge>
                  </td>
                  <td className="px-4 py-3 text-muted-foreground">
                    {agency.primary_contact_email ?? "—"}
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
