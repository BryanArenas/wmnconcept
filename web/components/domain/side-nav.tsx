"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  FilePlus2,
  ClipboardList,
  Receipt,
  Inbox,
  SendHorizonal,
  Building2,
  CalendarDays,
  ClipboardCheck,
  Users,
  Settings,
  type LucideIcon,
} from "lucide-react";

import type { Role, Surface } from "@/lib/types";
import { cn } from "@/lib/utils";

interface NavItem {
  href: string;
  label: string;
  icon: LucideIcon;
}

// Role-scoped nav (§7). Staff roles share the staff surface but differ in what
// they can act on; the manager's queue and the coordinator's dispatch are
// distinct entry points.
const NAV_BY_ROLE: Record<Role, NavItem[]> = {
  org_admin: [
    { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
    { href: "/requests", label: "Requests", icon: Inbox },
    { href: "/dispatch", label: "Dispatch", icon: SendHorizonal },
    { href: "/review", label: "Review queue", icon: ClipboardCheck },
    { href: "/calendar", label: "Calendar", icon: CalendarDays },
    { href: "/agencies", label: "Agencies", icon: Building2 },
    { href: "/team", label: "Team", icon: Users },
    { href: "/settings", label: "Settings", icon: Settings },
  ],
  coordinator: [
    { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
    { href: "/requests", label: "Requests", icon: Inbox },
    { href: "/dispatch", label: "Dispatch", icon: SendHorizonal },
    { href: "/calendar", label: "Calendar", icon: CalendarDays },
    { href: "/agencies", label: "Agencies", icon: Building2 },
    { href: "/team", label: "Team", icon: Users },
    { href: "/settings", label: "Settings", icon: Settings },
  ],
  manager: [
    { href: "/review", label: "Review queue", icon: ClipboardCheck },
    { href: "/settings", label: "Settings", icon: Settings },
  ],
  inspector: [
    { href: "/today", label: "Today", icon: ClipboardList },
    { href: "/settings", label: "Settings", icon: Settings },
  ],
};

// Agency users (M2) live in a separate table; their nav is kept here so the
// shell is ready for that surface. The external portal is namespaced under
// /agency/* to avoid Next route-group URL collisions with the staff surface
// (see docs/decisions/0001-agency-surface-url-namespace.md).
export const AGENCY_NAV: NavItem[] = [
  { href: "/agency/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "/agency/request/new", label: "Request inspection", icon: FilePlus2 },
  { href: "/agency/inspections", label: "My inspections", icon: ClipboardList },
  { href: "/agency/invoices", label: "Invoices", icon: Receipt },
];

export function navItemsForRole(role: Role): NavItem[] {
  return NAV_BY_ROLE[role] ?? [];
}

// Resolve the nav for a surface + role. The agency surface (M2) uses its own
// list; every staff/field role maps through NAV_BY_ROLE.
function itemsFor(surface: Surface, role: Role): NavItem[] {
  return surface === "agency" ? AGENCY_NAV : navItemsForRole(role);
}

export function SideNav({ role, surface }: { role: Role; surface: Surface }) {
  const pathname = usePathname();
  const items = itemsFor(surface, role);

  return (
    <nav className="flex flex-col gap-0.5" aria-label="Primary">
      {items.map((item) => {
        const active =
          pathname === item.href || pathname.startsWith(`${item.href}/`);
        const Icon = item.icon;

        return (
          <Link
            key={item.href}
            href={item.href}
            aria-current={active ? "page" : undefined}
            className={cn(
              "flex items-center gap-2.5 rounded-md px-3 py-2 text-body transition-colors",
              active
                ? "bg-background font-medium text-foreground shadow-[inset_2px_0_0_var(--color-primary)]"
                : "text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            <Icon size={16} strokeWidth={2} className="shrink-0" />
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
