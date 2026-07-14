import { BrandMark } from "@/components/domain/brand-mark";
import { Card, CardContent } from "@/components/ui/card";
import { PayForm } from "./pay-form";

// Public placeholder checkout reached from the invoice link emailed on
// scheduling. The invoice id (UUID) is the capability; the client form fetches
// the summary and simulates payment (no real charge until Stripe lands).
export default async function PayPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  return (
    <main className="flex min-h-dvh items-center justify-center bg-secondary px-5">
      <div className="w-full max-w-[420px]">
        <div className="mb-7 flex flex-col items-center gap-3 text-center">
          <BrandMark />
          <div>
            <p className="text-title tracking-tight">
              WINDMITIGATION<span className="text-primary">.NETWORK</span>
            </p>
            <p className="text-eyebrow uppercase text-muted-foreground">
              Secure checkout
            </p>
          </div>
        </div>

        <Card>
          <CardContent className="flex flex-col gap-5">
            <h1 className="font-serif text-display-md">Pay your invoice</h1>
            <PayForm id={id} />
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
