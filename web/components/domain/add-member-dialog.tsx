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
import type { Role, User } from "@/lib/types";
import { InviteLinkBox } from "@/components/domain/invite-link-box";

const schema = z.object({
  name: z.string().min(1, "Name is required"),
  email: z.string().email("Enter a valid email"),
  role: z.enum(["inspector", "coordinator", "manager", "org_admin"], {
    error: "Role is required",
  }),
  license_number: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

const ROLE_OPTIONS: { value: Role; label: string }[] = [
  { value: "inspector", label: "Inspector" },
  { value: "coordinator", label: "Coordinator" },
  { value: "manager", label: "Inspection manager" },
  { value: "org_admin", label: "Org admin" },
];

interface Props {
  // Roles the current staff member is allowed to hand out. Coordinators can
  // only invite inspectors; org_admins can invite any role.
  allowedRoles: Role[];
  onCreated: (user: User) => void;
}

export function AddMemberDialog({ allowedRoles, onCreated }: Props) {
  const [open, setOpen] = React.useState(false);
  const [serverError, setServerError] = React.useState<string | null>(null);
  const [inviteUrl, setInviteUrl] = React.useState<string | null>(null);
  const [invitedName, setInvitedName] = React.useState<string>("");

  const {
    register,
    control,
    handleSubmit,
    watch,
    reset,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { role: allowedRoles[0] },
  });

  const role = watch("role");
  const roleChoices = ROLE_OPTIONS.filter((r) => allowedRoles.includes(r.value));

  async function onSubmit(values: FormValues) {
    setServerError(null);

    const payload: Record<string, unknown> = {
      name: values.name,
      email: values.email,
      role: values.role,
    };
    if (values.role === "inspector" && values.license_number) {
      payload.license_number = values.license_number;
    }

    try {
      const created = await apiFetch<User & { invite_url: string }>(
        "/api/v1/users",
        { method: "POST", body: JSON.stringify({ user: payload }) },
      );
      onCreated(created);
      setInvitedName(created.name);
      setInviteUrl(created.invite_url);
      reset({ role: allowedRoles[0] });
    } catch (err) {
      if (err instanceof ApiError) {
        const fieldErrors = err.fieldErrors();
        let hasFieldErrors = false;
        (["name", "email", "role"] as const).forEach((f) => {
          if (fieldErrors[f]) {
            setError(f, { message: fieldErrors[f] });
            hasFieldErrors = true;
          }
        });
        if (!hasFieldErrors) setServerError(err.message);
      } else {
        setServerError("An unexpected error occurred.");
      }
    }
  }

  function handleOpenChange(next: boolean) {
    setOpen(next);
    if (!next) {
      reset({ role: allowedRoles[0] });
      setServerError(null);
      setInviteUrl(null);
      setInvitedName("");
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button>
          <Plus className="h-4 w-4" />
          Add member
        </Button>
      </DialogTrigger>

      <DialogContent className="sm:max-w-[440px]">
        <DialogHeader>
          <DialogTitle>{inviteUrl ? "Invitation created" : "Add team member"}</DialogTitle>
        </DialogHeader>

        {inviteUrl ? (
          <div className="flex flex-col gap-4">
            <p className="text-body text-muted-foreground">
              {invitedName} has been invited. Their account stays inactive until
              they set a password with the link below.
            </p>
            <InviteLinkBox url={inviteUrl} />
            <DialogFooter>
              <Button type="button" onClick={() => handleOpenChange(false)}>
                Done
              </Button>
            </DialogFooter>
          </div>
        ) : (
          <>
            <form
              id="add-member-form"
              onSubmit={handleSubmit(onSubmit)}
              className="flex flex-col gap-4"
            >
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="member-name">Full name *</Label>
                <Input id="member-name" placeholder="Ivan Inspector" {...register("name")} />
                {errors.name && (
                  <p className="text-label text-destructive">{errors.name.message}</p>
                )}
              </div>

              <div className="flex flex-col gap-1.5">
                <Label htmlFor="member-email">Email *</Label>
                <Input
                  id="member-email"
                  type="email"
                  placeholder="ivan@windmitigation.network"
                  {...register("email")}
                />
                {errors.email && (
                  <p className="text-label text-destructive">{errors.email.message}</p>
                )}
              </div>

              <div className="flex flex-col gap-1.5">
                <Label htmlFor="member-role">Role *</Label>
                <Controller
                  name="role"
                  control={control}
                  render={({ field }) => (
                    <Select onValueChange={field.onChange} value={field.value ?? ""}>
                      <SelectTrigger id="member-role">
                        <SelectValue placeholder="Select role" />
                      </SelectTrigger>
                      <SelectContent>
                        {roleChoices.map((r) => (
                          <SelectItem key={r.value} value={r.value}>
                            {r.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
                {errors.role && (
                  <p className="text-label text-destructive">{errors.role.message}</p>
                )}
              </div>

              {role === "inspector" && (
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="member-license">License number</Label>
                  <Input id="member-license" placeholder="HI-10482" {...register("license_number")} />
                </div>
              )}

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
              <Button type="submit" form="add-member-form" disabled={isSubmitting}>
                {isSubmitting ? "Inviting…" : "Send invite"}
              </Button>
            </DialogFooter>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
