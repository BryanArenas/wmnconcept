"use client";

import * as React from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Check } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent } from "@/components/ui/card";
import { apiFetch, ApiError } from "@/lib/api";
import type { Organization } from "@/lib/types";

const schema = z.object({
  name: z.string().min(1, "Company name is required"),
  primary_email: z.string().email("Enter a valid email").or(z.literal("")).optional(),
  phone: z.string().optional(),
  timezone: z.string().min(1, "Timezone is required"),
  brand_primary_hex: z
    .string()
    .regex(/^#[0-9a-fA-F]{6}$/, "Use a hex color like #E11D2A"),
});
type FormValues = z.infer<typeof schema>;

const TIMEZONES = [
  "America/New_York",
  "America/Chicago",
  "America/Denver",
  "America/Los_Angeles",
  "America/Phoenix",
];

export function CompanySettingsForm({
  initialOrganization,
}: {
  initialOrganization: Organization;
}) {
  const [saved, setSaved] = React.useState(false);
  const [serverError, setServerError] = React.useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: initialOrganization.name,
      primary_email: initialOrganization.primary_email ?? "",
      phone: initialOrganization.phone ?? "",
      timezone: initialOrganization.timezone,
      brand_primary_hex: initialOrganization.brand_primary_hex,
    },
  });

  async function onSubmit(values: FormValues) {
    setServerError(null);
    setSaved(false);
    try {
      await apiFetch("/api/v1/organization", {
        method: "PATCH",
        body: JSON.stringify({ organization: values }),
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 2500);
    } catch (err) {
      if (err instanceof ApiError) {
        const fields = err.fieldErrors();
        let hadField = false;
        (["name", "primary_email", "phone", "timezone", "brand_primary_hex"] as const).forEach(
          (f) => {
            if (fields[f]) {
              setError(f, { message: fields[f] });
              hadField = true;
            }
          },
        );
        if (!hadField) setServerError(err.message);
      } else {
        setServerError("Something went wrong. Please try again.");
      }
    }
  }

  return (
    <Card className="max-w-xl">
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="name">Company name</Label>
            <Input id="name" {...register("name")} />
            {errors.name && <p className="text-label text-destructive">{errors.name.message}</p>}
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="primary_email">Contact email</Label>
              <Input id="primary_email" type="email" {...register("primary_email")} />
              {errors.primary_email && (
                <p className="text-label text-destructive">{errors.primary_email.message}</p>
              )}
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="phone">Phone</Label>
              <Input id="phone" type="tel" {...register("phone")} />
            </div>
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="timezone">Timezone</Label>
              <select
                id="timezone"
                className="h-9 rounded-md border border-input bg-transparent px-3 text-body"
                {...register("timezone")}
              >
                {TIMEZONES.map((tz) => (
                  <option key={tz} value={tz}>
                    {tz.replace("America/", "").replace("_", " ")}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="brand_primary_hex">Brand color</Label>
              <div className="flex items-center gap-2">
                <Input id="brand_primary_hex" {...register("brand_primary_hex")} />
              </div>
              {errors.brand_primary_hex && (
                <p className="text-label text-destructive">{errors.brand_primary_hex.message}</p>
              )}
            </div>
          </div>

          {serverError && (
            <p className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-label text-destructive">
              {serverError}
            </p>
          )}

          <div className="flex items-center gap-3">
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? "Saving…" : "Save changes"}
            </Button>
            {saved && (
              <span className="flex items-center gap-1 text-label text-emerald-600">
                <Check className="h-4 w-4" /> Saved
              </span>
            )}
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
