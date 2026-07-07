"use client";

import type { Surface, User } from "@/lib/types";
import { BrandMark } from "@/components/domain/brand-mark";
import { SideNav } from "@/components/domain/side-nav";
import { MobileNav } from "@/components/domain/mobile-nav";
import { UserMenu } from "@/components/domain/user-menu";

const ROLE_LABEL: Record<User["role"], string> = {
  org_admin: "Org admin",
  coordinator: "Coordinator",
  manager: "Inspection manager",
  inspector: "Inspector",
};

// App shell (§7): sticky 56px top bar with the brand lockup + current user, a
// 210px hairline-right left nav, and a centered 1180px content column. The
// field surface (inspector) drops the sidebar for a phone-first single column.
export function AppShell({
  user,
  surface,
  children,
}: {
  user: User;
  surface: Surface;
  children: React.ReactNode;
}) {
  const isField = surface === "field";

  return (
    <div className="min-h-dvh bg-background">
      <header className="sticky top-0 z-40 h-14 border-b border-border bg-background">
        <div className="mx-auto flex h-full max-w-[1180px] items-center justify-between px-5 sm:px-7">
          <div className="flex items-center gap-3">
            <BrandMark />
            <div className="flex flex-col leading-tight">
              <span className="text-title tracking-tight">
                WINDMITIGATION<span className="text-primary">.NETWORK</span>
              </span>
              <span className="text-eyebrow uppercase text-muted-foreground">
                Inspection Operations
              </span>
            </div>
          </div>
          <UserMenu name={user.name} sublabel={ROLE_LABEL[user.role]} />
        </div>
      </header>

      <div className="mx-auto flex max-w-[1180px]">
        {!isField && (
          <aside className="hidden w-[210px] shrink-0 border-r border-border md:block">
            <div className="sticky top-14 p-3">
              <SideNav role={user.role} surface={surface} />
            </div>
          </aside>
        )}

        <main
          id="main-content"
          className={
            isField
              ? "mx-auto w-full max-w-[560px] px-5 py-7 pb-20 md:pb-7"
              : "min-w-0 flex-1 px-5 py-7 pb-20 sm:px-7 md:pb-7"
          }
        >
          {children}
        </main>
      </div>

      <MobileNav role={user.role} surface={surface} />
    </div>
  );
}
