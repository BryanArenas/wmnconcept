"use client";

import { useEffect, useState } from "react";

import { API_BASE_URL, apiFetch } from "@/lib/api";
import { Button } from "@/components/ui/button";

// Staff/agency login initiation. OmniAuth's request phase is a POST protected
// by omniauth-rails_csrf_protection, so we submit a real top-level form POST to
// Rails carrying the authenticity token from the XSRF-TOKEN cookie. A prior GET
// (health) guarantees the session + token cookie exist before we submit.
export function LoginButtons() {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    apiFetch("/api/v1/health")
      .catch(() => undefined)
      .finally(() => setReady(true));
  }, []);

  function startOauth(provider: "google_oauth2" | "github") {
    const form = document.createElement("form");
    form.method = "POST";
    form.action = `${API_BASE_URL}/auth/${provider}`;

    const token = readCookie("XSRF-TOKEN");
    if (token) {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = "authenticity_token";
      input.value = token;
      form.appendChild(input);
    }

    document.body.appendChild(form);
    form.submit();
  }

  return (
    <div className="flex flex-col gap-3">
      <Button
        variant="outline"
        className="w-full justify-center"
        disabled={!ready}
        onClick={() => startOauth("google_oauth2")}
      >
        Continue with Google
      </Button>
      <Button
        variant="outline"
        className="w-full justify-center"
        disabled={!ready}
        onClick={() => startOauth("github")}
      >
        Continue with GitHub
      </Button>
    </div>
  );
}

function readCookie(name: string): string | null {
  const match = document.cookie.match(
    new RegExp(`(?:^|; )${name}=([^;]*)`),
  );
  return match ? decodeURIComponent(match[1]) : null;
}
