"use client";

import * as React from "react";
import { Check, Copy } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

// Shows a provisioned account's activation link with a copy button. This is the
// path that makes provisioning work with no email server configured: the admin
// hands (or sends) the link to the invitee, who follows it to set a password
// and confirm their email. The invite email carries the same link when a
// delivery adapter is set up.
export function InviteLinkBox({ url }: { url: string }) {
  const [copied, setCopied] = React.useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard blocked (e.g. non-HTTPS) — the field is selectable as fallback.
    }
  }

  return (
    <div className="flex flex-col gap-2 rounded-md border border-border bg-muted/40 p-3">
      <p className="text-label font-medium text-foreground">Invitation link</p>
      <p className="text-label text-muted-foreground">
        Share this link so they can set a password and activate their account.
        It expires in 14 days.
      </p>
      <div className="flex items-center gap-2">
        <Input
          readOnly
          value={url}
          onFocus={(e) => e.currentTarget.select()}
          className="font-mono text-label"
          aria-label="Invitation link"
        />
        <Button type="button" variant="outline" size="icon" onClick={copy} aria-label="Copy link">
          {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
        </Button>
      </div>
    </div>
  );
}
