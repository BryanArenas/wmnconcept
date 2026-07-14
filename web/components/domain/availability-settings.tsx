"use client";

import * as React from "react";
import { Trash2, CalendarOff, Plus, Loader2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent } from "@/components/ui/card";
import { InfoHint } from "@/components/ui/info-hint";
import { apiFetch, ApiError } from "@/lib/api";
import type { AvailabilityBlock } from "@/lib/types";

function fmt(iso: string) {
  return new Date(iso).toLocaleString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export function AvailabilitySettings() {
  const [blocks, setBlocks] = React.useState<AvailabilityBlock[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  const [date, setDate] = React.useState("");
  const [allDay, setAllDay] = React.useState(false);
  const [start, setStart] = React.useState("09:00");
  const [end, setEnd] = React.useState("17:00");
  const [reason, setReason] = React.useState("");
  const [saving, setSaving] = React.useState(false);

  React.useEffect(() => {
    apiFetch<{ data: AvailabilityBlock[] }>("/api/v1/availability_blocks")
      .then((r) => setBlocks(r.data))
      .catch((err) => setError(err instanceof ApiError ? err.message : "Could not load blocks."))
      .finally(() => setLoading(false));
  }, []);

  async function addBlock(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!date) {
      setError("Pick a date to block out.");
      return;
    }
    const startsAt = allDay ? `${date}T00:00` : `${date}T${start}`;
    const endsAt = allDay ? `${date}T23:59` : `${date}T${end}`;

    setSaving(true);
    try {
      const { data } = await apiFetch<{ data: AvailabilityBlock }>(
        "/api/v1/availability_blocks",
        {
          method: "POST",
          body: JSON.stringify({
            availability_block: {
              starts_at: new Date(startsAt).toISOString(),
              ends_at: new Date(endsAt).toISOString(),
              all_day: allDay,
              reason: reason || undefined,
            },
          }),
        },
      );
      setBlocks((prev) =>
        [...prev, data].sort((a, b) => a.starts_at.localeCompare(b.starts_at)),
      );
      setDate("");
      setReason("");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Could not add the block.");
    } finally {
      setSaving(false);
    }
  }

  async function remove(id: string) {
    setBlocks((prev) => prev.filter((b) => b.id !== id));
    try {
      await apiFetch(`/api/v1/availability_blocks/${id}`, { method: "DELETE" });
    } catch {
      // Re-fetch on failure to stay consistent.
      const r = await apiFetch<{ data: AvailabilityBlock[] }>("/api/v1/availability_blocks").catch(
        () => null,
      );
      if (r) setBlocks(r.data);
    }
  }

  return (
    <div className="flex max-w-2xl flex-col gap-6">
      <Card>
        <CardContent>
          <form onSubmit={addBlock} className="flex flex-col gap-4">
            <div className="flex items-center gap-1.5">
              <h3 className="text-title text-foreground">Block out time</h3>
              <InfoHint label="About availability">
                Time you block here marks you unavailable, so you aren't scheduled for
                inspections then.
              </InfoHint>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="block-date">Date</Label>
                <Input
                  id="block-date"
                  type="date"
                  value={date}
                  onChange={(e) => setDate(e.target.value)}
                />
              </div>
              <div className="flex items-end">
                <label className="flex items-center gap-2 py-2 text-body">
                  <input
                    type="checkbox"
                    checked={allDay}
                    onChange={(e) => setAllDay(e.target.checked)}
                    className="h-4 w-4"
                  />
                  All day
                </label>
              </div>
            </div>

            {!allDay && (
              <div className="grid grid-cols-2 gap-3">
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="block-start">From</Label>
                  <Input
                    id="block-start"
                    type="time"
                    value={start}
                    onChange={(e) => setStart(e.target.value)}
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="block-end">To</Label>
                  <Input
                    id="block-end"
                    type="time"
                    value={end}
                    onChange={(e) => setEnd(e.target.value)}
                  />
                </div>
              </div>
            )}

            <div className="flex flex-col gap-1.5">
              <Label htmlFor="block-reason">Reason (optional)</Label>
              <Input
                id="block-reason"
                placeholder="Vacation, appointment, etc."
                value={reason}
                onChange={(e) => setReason(e.target.value)}
              />
            </div>

            {error && (
              <p role="alert" className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-label text-destructive">
                {error}
              </p>
            )}

            <Button type="submit" disabled={saving} className="self-start">
              <Plus className="mr-1.5 h-4 w-4" />
              {saving ? "Adding…" : "Block out time"}
            </Button>
          </form>
        </CardContent>
      </Card>

      <div className="flex flex-col gap-2">
        <h3 className="text-label font-semibold uppercase tracking-wide text-muted-foreground">
          Upcoming blocks
        </h3>

        {loading ? (
          <div className="flex items-center gap-2 py-6 text-body text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" /> Loading…
          </div>
        ) : blocks.length === 0 ? (
          <div className="flex flex-col items-center gap-2 rounded-lg border border-dashed border-border py-10 text-center text-muted-foreground">
            <CalendarOff className="h-7 w-7 opacity-40" />
            <p className="text-body">No blocked time yet.</p>
          </div>
        ) : (
          <ul className="overflow-hidden rounded-lg border border-border">
            {blocks.map((b, i) => (
              <li
                key={b.id}
                className={
                  "flex items-center justify-between gap-3 px-4 py-3 " +
                  (i < blocks.length - 1 ? "border-b border-border" : "")
                }
              >
                <div>
                  <p className="text-body font-medium text-foreground">
                    {b.all_day
                      ? `${new Date(b.starts_at).toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" })} · All day`
                      : `${fmt(b.starts_at)} – ${new Date(b.ends_at).toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" })}`}
                  </p>
                  {b.reason && <p className="text-label text-muted-foreground">{b.reason}</p>}
                </div>
                <Button
                  size="icon"
                  variant="ghost"
                  aria-label="Remove block"
                  onClick={() => remove(b.id)}
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
