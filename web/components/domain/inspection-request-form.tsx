"use client";

import * as React from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { CheckCircle2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { apiFetch, ApiError } from "@/lib/api";
import { cn } from "@/lib/utils";
import type { InspectionTypeConfig, InspectionRequest } from "@/lib/types";

const schema = z.object({
  requested_types: z
    .array(z.string())
    .min(1, "Select at least one inspection type"),
  address: z.string().min(1, "Address is required"),
  city: z.string().min(1, "City is required"),
  state: z.string().min(1, "State is required"),
  zip: z.string().min(5, "ZIP code is required"),
  homeowner_name: z.string().min(1, "Homeowner name is required"),
  homeowner_email: z
    .string()
    .email("Enter a valid email")
    .optional()
    .or(z.literal("")),
  homeowner_phone: z.string().optional(),
  preferred_dates: z.string().optional(),
  notes: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

interface Props {
  configs: InspectionTypeConfig[];
}

export function InspectionRequestForm({ configs }: Props) {
  const [submitted, setSubmitted] = React.useState(false);
  const [serverError, setServerError] = React.useState<string | null>(null);

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { requested_types: [], state: "FL" },
  });

  const selectedTypes = watch("requested_types");

  const totalCents = selectedTypes.reduce((sum, type) => {
    const cfg = configs.find((c) => c.inspection_type === type);
    return sum + (cfg?.price_cents ?? 0);
  }, 0);

  function toggleType(type: string) {
    const current = selectedTypes;
    const next = current.includes(type)
      ? current.filter((t) => t !== type)
      : [...current, type];
    setValue("requested_types", next, { shouldValidate: true });
  }

  async function onSubmit(values: FormValues) {
    setServerError(null);
    try {
      await apiFetch<{ data: InspectionRequest }>("/api/v1/inspection_requests", {
        method: "POST",
        body: JSON.stringify({
          property: {
            address: values.address,
            city: values.city,
            state: values.state,
            zip: values.zip,
          },
          homeowner: {
            name: values.homeowner_name,
            email: values.homeowner_email || undefined,
            phone: values.homeowner_phone || undefined,
          },
          inspection_request: {
            requested_types: values.requested_types,
            preferred_dates: values.preferred_dates || undefined,
            notes: values.notes || undefined,
          },
        }),
      });
      setSubmitted(true);
    } catch (err) {
      if (err instanceof ApiError) {
        const fe = err.fieldErrors();
        const fieldMap: Partial<Record<string, keyof FormValues>> = {
          requested_types: "requested_types",
          address: "address",
          city: "city",
          zip: "zip",
        };
        let hasField = false;
        for (const [raw, formKey] of Object.entries(fieldMap)) {
          if (fe[raw] && formKey) {
            setError(formKey, { message: fe[raw] });
            hasField = true;
          }
        }
        if (!hasField) setServerError(err.message);
      } else {
        setServerError("An unexpected error occurred. Please try again.");
      }
    }
  }

  if (submitted) {
    return (
      <div className="flex flex-col items-center gap-4 rounded-lg border border-border bg-card p-10 text-center">
        <CheckCircle2 className="h-10 w-10 text-primary" />
        <div>
          <p className="text-title">Request submitted</p>
          <p className="mt-1 text-body text-muted-foreground">
            The WMN office will review your request and assign an inspector.
          </p>
        </div>
        <Button variant="outline" onClick={() => (window.location.href = "/agency/dashboard")}>
          Back to dashboard
        </Button>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-8">
      {/* Inspection types */}
      <section className="flex flex-col gap-3">
        <div>
          <p className="text-title text-sm font-medium">Inspection type(s)</p>
          <p className="text-label text-muted-foreground">
            Select all that apply. Each type becomes a separate inspection.
          </p>
        </div>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-4">
          {configs.map((cfg) => (
            <TypeChip
              key={cfg.inspection_type}
              config={cfg}
              selected={selectedTypes.includes(cfg.inspection_type)}
              onToggle={() => toggleType(cfg.inspection_type)}
            />
          ))}
        </div>
        {errors.requested_types && (
          <p className="text-label text-destructive">
            {errors.requested_types.message}
          </p>
        )}
        {totalCents > 0 && (
          <p className="text-sm font-medium">
            Estimated total:{" "}
            <span className="text-primary">${(totalCents / 100).toFixed(2)}</span>
          </p>
        )}
      </section>

      {/* Property */}
      <section className="flex flex-col gap-3">
        <p className="text-title text-sm font-medium">Property</p>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="address">Street address *</Label>
          <Input
            id="address"
            placeholder="123 Hendry St"
            {...register("address")}
          />
          {errors.address && (
            <p className="text-label text-destructive">{errors.address.message}</p>
          )}
        </div>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div className="col-span-2 flex flex-col gap-1.5">
            <Label htmlFor="city">City *</Label>
            <Input id="city" placeholder="Fort Myers" {...register("city")} />
            {errors.city && (
              <p className="text-label text-destructive">{errors.city.message}</p>
            )}
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="state">State</Label>
            <Input id="state" {...register("state")} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="zip">ZIP *</Label>
            <Input id="zip" placeholder="33901" {...register("zip")} />
            {errors.zip && (
              <p className="text-label text-destructive">{errors.zip.message}</p>
            )}
          </div>
        </div>
      </section>

      {/* Homeowner */}
      <section className="flex flex-col gap-3">
        <p className="text-title text-sm font-medium">Homeowner</p>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="homeowner_name">Full name *</Label>
            <Input
              id="homeowner_name"
              placeholder="Dana Homeowner"
              {...register("homeowner_name")}
            />
            {errors.homeowner_name && (
              <p className="text-label text-destructive">
                {errors.homeowner_name.message}
              </p>
            )}
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="homeowner_email">Email</Label>
            <Input
              id="homeowner_email"
              type="email"
              placeholder="owner@example.com"
              {...register("homeowner_email")}
            />
            {errors.homeowner_email && (
              <p className="text-label text-destructive">
                {errors.homeowner_email.message}
              </p>
            )}
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="homeowner_phone">Phone</Label>
            <Input
              id="homeowner_phone"
              type="tel"
              placeholder="239-555-0300"
              {...register("homeowner_phone")}
            />
          </div>
        </div>
      </section>

      {/* Optional details */}
      <section className="flex flex-col gap-3">
        <p className="text-title text-sm font-medium">Optional details</p>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="preferred_dates">Preferred dates / availability</Label>
            <Textarea
              id="preferred_dates"
              placeholder="e.g. Weekday mornings, after 9 AM"
              rows={3}
              {...register("preferred_dates")}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="notes">Notes for the inspector</Label>
            <Textarea
              id="notes"
              placeholder="e.g. Gate code 1234, dog in backyard"
              rows={3}
              {...register("notes")}
            />
          </div>
        </div>
      </section>

      {serverError && (
        <p className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-label text-destructive">
          {serverError}
        </p>
      )}

      <div className="flex justify-end">
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting ? "Submitting…" : "Submit request"}
        </Button>
      </div>
    </form>
  );
}

// A selectable type chip showing label + formatted price.
function TypeChip({
  config,
  selected,
  onToggle,
}: {
  config: InspectionTypeConfig;
  selected: boolean;
  onToggle: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onToggle}
      aria-pressed={selected}
      className={cn(
        "flex flex-col gap-0.5 rounded-lg border px-4 py-3 text-left text-sm transition-colors",
        selected
          ? "border-primary bg-primary/5 text-primary"
          : "border-border bg-background hover:border-primary/40",
      )}
    >
      <span className="font-medium leading-snug">{config.label}</span>
      <span
        className={cn(
          "text-xs",
          selected ? "text-primary/70" : "text-muted-foreground",
        )}
      >
        ${(config.price_cents / 100).toFixed(2)}
      </span>
    </button>
  );
}
