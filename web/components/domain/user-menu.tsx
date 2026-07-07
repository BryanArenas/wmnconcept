"use client";

import { useState } from "react";
import { LogOut } from "lucide-react";

import { apiFetch } from "@/lib/api";
import { Button } from "@/components/ui/button";

// Right side of the top bar (§7): current user name + role sublabel. Role comes
// from the session, never a switcher (spec §13). Sign-out clears the shared
// cookie session and returns to the login entry.
export function UserMenu({
  name,
  sublabel,
}: {
  name: string;
  sublabel: string;
}) {
  const [signingOut, setSigningOut] = useState(false);

  async function signOut() {
    setSigningOut(true);
    try {
      await apiFetch("/api/v1/session", { method: "DELETE" });
    } catch {
      // Even if the request fails, drop the user at the login entry.
    } finally {
      window.location.assign("/login");
    }
  }

  return (
    <div className="flex items-center gap-3">
      <div className="hidden flex-col items-end leading-tight sm:flex">
        <span className="text-body font-medium text-foreground">{name}</span>
        <span className="text-eyebrow uppercase text-muted-foreground">
          {sublabel}
        </span>
      </div>
      <Button
        variant="ghost"
        size="icon"
        onClick={signOut}
        disabled={signingOut}
        aria-label="Sign out"
      >
        <LogOut size={16} strokeWidth={2} />
      </Button>
    </div>
  );
}
