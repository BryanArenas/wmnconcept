import { BrandMark } from "@/components/domain/brand-mark";
import { Card, CardContent } from "@/components/ui/card";
import { LoginButtons } from "./login-buttons";

const ERROR_COPY: Record<string, string> = {
  not_authorized:
    "That account isn't set up for Wind Mitigation Network. Ask your admin for an invite.",
  auth_failed: "Sign-in didn't complete. Please try again.",
  invalid_credentials: "Sign-in didn't complete. Please try again.",
};

// Login entry (§10). No AppShell — a bare, centered card. Reads ?error= set by
// the Rails callback when auth is refused.
export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  const message = error ? (ERROR_COPY[error] ?? ERROR_COPY.auth_failed) : null;

  return (
    <main className="flex min-h-dvh items-center justify-center bg-secondary px-5">
      <div className="w-full max-w-[380px]">
        <div className="mb-7 flex flex-col items-center gap-3 text-center">
          <BrandMark />
          <div>
            <p className="text-title tracking-tight">
              WINDMITIGATION<span className="text-primary">.NETWORK</span>
            </p>
            <p className="text-eyebrow uppercase text-muted-foreground">
              Inspection Operations
            </p>
          </div>
        </div>

        <Card>
          <CardContent className="flex flex-col gap-5">
            <div className="flex flex-col gap-1">
              <h1 className="font-serif text-display-md">Sign in</h1>
              <p className="text-body text-muted-foreground">
                Staff and partner agencies sign in with Google or GitHub.
              </p>
            </div>

            {message && (
              <p
                role="alert"
                className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-body text-destructive"
              >
                {message}
              </p>
            )}

            <LoginButtons />
          </CardContent>
        </Card>

        <p className="mt-5 text-center text-body text-muted-foreground">
          Reports delivered to every party, usually within 24 hours.
        </p>
      </div>
    </main>
  );
}
