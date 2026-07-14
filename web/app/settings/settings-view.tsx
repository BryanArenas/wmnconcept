"use client";

import * as React from "react";
import { cn } from "@/lib/utils";
import type { Organization, User } from "@/lib/types";
import { CompanySettingsForm } from "@/components/domain/company-settings-form";
import { UsersPermissionsTable } from "@/components/domain/users-permissions-table";
import { AvailabilitySettings } from "@/components/domain/availability-settings";
import { ProfileCard } from "@/components/domain/profile-card";

interface Props {
  user: User;
  initialOrganization: Organization | null;
  initialMembers: User[];
}

export function SettingsView({ user, initialOrganization, initialMembers }: Props) {
  const tabs = React.useMemo(() => {
    if (user.role === "org_admin") return ["Company", "Team & permissions", "Profile"];
    if (user.role === "inspector") return ["Availability", "Profile"];
    return ["Profile"];
  }, [user.role]);

  const [active, setActive] = React.useState(tabs[0]);

  return (
    <div className="flex flex-col gap-6">
      <div className="flex gap-1 border-b border-border" role="tablist">
        {tabs.map((tab) => (
          <button
            key={tab}
            role="tab"
            aria-selected={active === tab}
            onClick={() => setActive(tab)}
            className={cn(
              "-mb-px border-b-2 px-3 py-2 text-body transition-colors",
              active === tab
                ? "border-primary font-medium text-foreground"
                : "border-transparent text-muted-foreground hover:text-foreground",
            )}
          >
            {tab}
          </button>
        ))}
      </div>

      <div>
        {active === "Company" && initialOrganization && (
          <CompanySettingsForm initialOrganization={initialOrganization} />
        )}
        {active === "Team & permissions" && (
          <UsersPermissionsTable initialMembers={initialMembers} currentUserId={user.id} />
        )}
        {active === "Availability" && <AvailabilitySettings />}
        {active === "Profile" && <ProfileCard user={user} />}
      </div>
    </div>
  );
}
