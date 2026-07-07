"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { Role, Surface } from "@/lib/types";
import { navItemsForRole, AGENCY_NAV } from "@/components/domain/side-nav";
import { cn } from "@/lib/utils";

export function MobileNav({ role, surface }: { role: Role; surface: Surface }) {
  const pathname = usePathname();
  const items = surface === "agency" ? AGENCY_NAV : navItemsForRole(role);

  if (items.length === 0) return null;

  return (
    <nav
      aria-label="Mobile navigation"
      className="fixed inset-x-0 bottom-0 z-40 border-t border-border bg-background md:hidden"
    >
      <div className="mx-auto flex max-w-[560px] items-stretch justify-around">
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
                "flex min-h-[48px] min-w-[48px] flex-1 flex-col items-center justify-center gap-0.5 py-1.5 text-center transition-colors",
                active
                  ? "text-primary"
                  : "text-muted-foreground hover:text-foreground",
              )}
            >
              <Icon size={20} strokeWidth={active ? 2.5 : 2} aria-hidden />
              <span className="text-[10px] font-medium leading-tight">
                {item.label}
              </span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
