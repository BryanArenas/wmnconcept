import { BrandMark } from "@/components/domain/brand-mark";
import { Card, CardContent } from "@/components/ui/card";
import { AcceptInviteForm } from "./accept-invite-form";

// Public account-activation page reached from the invite link. Reads the signed
// token + surface type from the query and hands them to the client form, which
// validates the token and lets the invitee set their password.
export default async function AcceptInvitePage({
  searchParams,
}: {
  searchParams: Promise<{ token?: string; type?: string }>;
}) {
  const { token = "", type = "" } = await searchParams;

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
              Activate your account
            </p>
          </div>
        </div>

        <Card>
          <CardContent className="flex flex-col gap-5">
            <h1 className="font-serif text-display-md">Set your password</h1>
            <AcceptInviteForm token={token} type={type} />
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
