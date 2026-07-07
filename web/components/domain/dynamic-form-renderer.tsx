"use client";

import * as React from "react";
import { useForm } from "react-hook-form";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { FormField, FormSchema } from "@/lib/types";

interface Props {
  schema: FormSchema;
  defaultValues?: Record<string, unknown>;
  onSave: (responses: Record<string, unknown>) => Promise<void>;
  disabled?: boolean;
}

export function DynamicFormRenderer({
  schema,
  defaultValues = {},
  onSave,
  disabled = false,
}: Props) {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting, isDirty },
  } = useForm<Record<string, unknown>>({ defaultValues });

  return (
    <form
      onSubmit={handleSubmit(onSave)}
      className="flex flex-col gap-5"
    >
      {schema.fields.map((field) => (
        <FieldRow
          key={field.key}
          field={field}
          register={register}
          error={errors[field.key]?.message as string | undefined}
          disabled={disabled}
        />
      ))}

      {!disabled && (
        <Button
          type="submit"
          disabled={isSubmitting || !isDirty}
          className="self-start"
        >
          {isSubmitting ? "Saving…" : "Save form"}
        </Button>
      )}
    </form>
  );
}

function FieldRow({
  field,
  register,
  error,
  disabled,
}: {
  field: FormField;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  register: any;
  error?: string;
  disabled: boolean;
}) {
  const inputClass = cn(
    "flex h-9 w-full rounded-md border border-input bg-background px-3 py-2 text-sm",
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
    "disabled:cursor-not-allowed disabled:opacity-50",
  );

  const validation = field.required
    ? { required: `${field.label} is required` }
    : {};

  return (
    <div className="flex flex-col gap-1.5">
      <Label htmlFor={field.key}>
        {field.label}
        {field.required && (
          <span className="ml-1 text-destructive" aria-hidden>*</span>
        )}
      </Label>

      {field.type === "select" && field.options ? (
        <select
          id={field.key}
          className={inputClass}
          disabled={disabled}
          {...register(field.key, validation)}
        >
          <option value="">Select…</option>
          {field.options.map((opt) => (
            <option key={opt} value={opt}>
              {opt}
            </option>
          ))}
        </select>
      ) : field.type === "boolean" ? (
        <div className="flex items-center gap-2">
          <input
            id={field.key}
            type="checkbox"
            className="h-4 w-4 rounded border border-input"
            disabled={disabled}
            {...register(field.key)}
          />
          <span className="text-sm text-muted-foreground">{field.label}</span>
        </div>
      ) : field.type === "number" ? (
        <input
          id={field.key}
          type="number"
          className={inputClass}
          disabled={disabled}
          {...register(field.key, { ...validation, valueAsNumber: true })}
        />
      ) : (
        <input
          id={field.key}
          type="text"
          className={inputClass}
          disabled={disabled}
          {...register(field.key, validation)}
        />
      )}

      {error && (
        <p className="text-label text-destructive">{error}</p>
      )}
    </div>
  );
}
