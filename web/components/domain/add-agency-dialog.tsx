"use client";

import * as React from "react";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { apiFetch, ApiError } from "@/lib/api";
import type { Agency } from "@/lib/types";

const schema = z
  .object({
    name: z.string().min(1, "Name is required"),
    type: z.enum(["insurance", "real_estate", "other"], {
      error: "Type is required",
    }),
    billing_mode: z.enum(["fixed_rate", "commission"], {
      error: "Billing mode is required",
    }),
    commission_rate: z.string().optional(),
    primary_contact_email: z
      .string()
      .email("Enter a valid email")
      .optional()
      .or(z.literal("")),
    phone: z.string().optional(),
    // Optional first partner login
    contact_name: z.string().optional(),
    contact_email: z
      .string()
      .email("Enter a valid email")
      .optional()
      .or(z.literal("")),
  })
  .superRefine((data, ctx) => {
    if (data.billing_mode === "commission") {
      const rate = parseFloat(data.commission_rate ?? "");
      if (isNaN(rate) || rate <= 0 || rate > 1) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["commission_rate"],
          message: "Enter a commission rate between 0 and 1 (e.g. 0.15)",
        });
      }
    }
  });

type FormValues = z.infer<typeof schema>;

interface Props {
  onCreated: (agency: Agency) => void;
}

export function AddAgencyDialog({ onCreated }: Props) {
  const [open, setOpen] = React.useState(false);
  const [serverError, setServerError] = React.useState<string | null>(null);

  const {
    register,
    control,
    handleSubmit,
    watch,
    reset,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  const billingMode = watch("billing_mode");

  async function onSubmit(values: FormValues) {
    setServerError(null);

    const agencyPayload: Record<string, unknown> = {
      name: values.name,
      type: values.type,
      billing_mode: values.billing_mode,
      primary_contact_email: values.primary_contact_email || undefined,
      phone: values.phone || undefined,
    };

    if (values.billing_mode === "commission") {
      agencyPayload.commission_rate = parseFloat(values.commission_rate ?? "0");
    }

    const body: Record<string, unknown> = { agency: agencyPayload };

    if (values.contact_email) {
      body.agency_user = {
        name: values.contact_name || undefined,
        email: values.contact_email,
      };
    }

    try {
      const { data } = await apiFetch<{ data: Agency }>("/api/v1/agencies", {
        method: "POST",
        body: JSON.stringify(body),
      });
      onCreated(data);
      reset();
      setOpen(false);
    } catch (err) {
      if (err instanceof ApiError) {
        const fieldErrors = err.fieldErrors();
        // Map rail field names to form field names
        const fieldMap: Record<string, keyof FormValues> = {
          name: "name",
          type: "type",
          billing_mode: "billing_mode",
          commission_rate: "commission_rate",
          primary_contact_email: "primary_contact_email",
          phone: "phone",
        };
        let hasFieldErrors = false;
        for (const [field, formField] of Object.entries(fieldMap)) {
          if (fieldErrors[field]) {
            setError(formField, { message: fieldErrors[field] });
            hasFieldErrors = true;
          }
        }
        if (!hasFieldErrors) {
          setServerError(err.message);
        }
      } else {
        setServerError("An unexpected error occurred.");
      }
    }
  }

  function handleOpenChange(next: boolean) {
    setOpen(next);
    if (!next) {
      reset();
      setServerError(null);
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button>
          <Plus className="h-4 w-4" />
          Add agency
        </Button>
      </DialogTrigger>

      <DialogContent className="sm:max-w-[480px]">
        <DialogHeader>
          <DialogTitle>Add agency</DialogTitle>
        </DialogHeader>

        <form
          id="add-agency-form"
          onSubmit={handleSubmit(onSubmit)}
          className="flex flex-col gap-4"
        >
          {/* Agency details */}
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="name">Agency name *</Label>
            <Input
              id="name"
              placeholder="Gulf Coast Insurance"
              {...register("name")}
            />
            {errors.name && (
              <p className="text-label text-destructive">{errors.name.message}</p>
            )}
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="type">Type *</Label>
              <Controller
                name="type"
                control={control}
                render={({ field }) => (
                  <Select onValueChange={field.onChange} value={field.value ?? ""}>
                    <SelectTrigger id="type">
                      <SelectValue placeholder="Select type" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="insurance">Insurance</SelectItem>
                      <SelectItem value="real_estate">Real estate</SelectItem>
                      <SelectItem value="other">Other</SelectItem>
                    </SelectContent>
                  </Select>
                )}
              />
              {errors.type && (
                <p className="text-label text-destructive">{errors.type.message}</p>
              )}
            </div>

            <div className="flex flex-col gap-1.5">
              <Label htmlFor="billing_mode">Billing *</Label>
              <Controller
                name="billing_mode"
                control={control}
                render={({ field }) => (
                  <Select onValueChange={field.onChange} value={field.value ?? ""}>
                    <SelectTrigger id="billing_mode">
                      <SelectValue placeholder="Select billing" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="fixed_rate">Fixed rate</SelectItem>
                      <SelectItem value="commission">Commission</SelectItem>
                    </SelectContent>
                  </Select>
                )}
              />
              {errors.billing_mode && (
                <p className="text-label text-destructive">
                  {errors.billing_mode.message}
                </p>
              )}
            </div>
          </div>

          {billingMode === "commission" && (
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="commission_rate">Commission rate *</Label>
              <Input
                id="commission_rate"
                type="number"
                step="0.01"
                min="0.01"
                max="1"
                placeholder="0.15"
                {...register("commission_rate")}
              />
              <p className="text-label text-muted-foreground">
                Decimal fraction — e.g. 0.15 for 15 %
              </p>
              {errors.commission_rate && (
                <p className="text-label text-destructive">
                  {errors.commission_rate.message}
                </p>
              )}
            </div>
          )}

          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="primary_contact_email">Contact email</Label>
              <Input
                id="primary_contact_email"
                type="email"
                placeholder="ops@agency.example"
                {...register("primary_contact_email")}
              />
              {errors.primary_contact_email && (
                <p className="text-label text-destructive">
                  {errors.primary_contact_email.message}
                </p>
              )}
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="phone">Phone</Label>
              <Input
                id="phone"
                type="tel"
                placeholder="239-555-0200"
                {...register("phone")}
              />
            </div>
          </div>

          {/* Divider + optional first portal login */}
          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t border-border" />
            </div>
            <div className="relative flex justify-center">
              <span className="bg-background px-2 text-label text-muted-foreground">
                First partner login (optional)
              </span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="contact_name">Contact name</Label>
              <Input
                id="contact_name"
                placeholder="Pat Partner"
                {...register("contact_name")}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="contact_email">Contact email</Label>
              <Input
                id="contact_email"
                type="email"
                placeholder="pat@agency.example"
                {...register("contact_email")}
              />
              {errors.contact_email && (
                <p className="text-label text-destructive">
                  {errors.contact_email.message}
                </p>
              )}
            </div>
          </div>

          {serverError && (
            <p className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-label text-destructive">
              {serverError}
            </p>
          )}
        </form>

        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => handleOpenChange(false)}
            disabled={isSubmitting}
          >
            Cancel
          </Button>
          <Button type="submit" form="add-agency-form" disabled={isSubmitting}>
            {isSubmitting ? "Saving…" : "Add agency"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
