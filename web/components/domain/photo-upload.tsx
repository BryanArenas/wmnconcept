"use client";

import * as React from "react";
import { Camera, CheckCircle2, Loader2, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { apiFetch, ApiError } from "@/lib/api";
import { cn } from "@/lib/utils";
import type { InspectionPhoto } from "@/lib/types";

interface Props {
  inspectionId: string;
  photos: InspectionPhoto[];
  onUploaded: (photo: InspectionPhoto) => void;
  disabled?: boolean;
}

type UploadStatus = "idle" | "requesting" | "uploading" | "confirming" | "done" | "error";

interface PendingUpload {
  file: File;
  status: UploadStatus;
  error?: string;
  photoId?: string;
}

export function PhotoUpload({
  inspectionId,
  photos,
  onUploaded,
  disabled = false,
}: Props) {
  const [pending, setPending] = React.useState<PendingUpload[]>([]);
  const inputRef = React.useRef<HTMLInputElement>(null);

  const uploadedPhotos = photos.filter((p) => p.upload_state === "uploaded");

  async function handleFiles(files: FileList | null) {
    if (!files || files.length === 0) return;

    const newUploads: PendingUpload[] = Array.from(files).map((f) => ({
      file: f,
      status: "idle" as UploadStatus,
    }));

    setPending((prev) => [...prev, ...newUploads]);

    for (let i = 0; i < newUploads.length; i++) {
      const idx = pending.length + i;

      const setStatus = (status: UploadStatus, extras: Partial<PendingUpload> = {}) =>
        setPending((prev) =>
          prev.map((u, j) => (j === idx ? { ...u, status, ...extras } : u)),
        );

      try {
        // Step 1: request presigned URL
        setStatus("requesting");
        const presignRes = await apiFetch<{
          data: InspectionPhoto;
          presigned_url: string;
        }>(`/api/v1/inspections/${inspectionId}/photos`, {
          method: "POST",
          body: JSON.stringify({
            photo: {
              filename: newUploads[i].file.name,
              content_type: newUploads[i].file.type || "image/jpeg",
            },
          }),
        });

        const photoId = presignRes.data.id;
        const presignedUrl = presignRes.presigned_url;
        setStatus("uploading", { photoId });

        // Step 2: PUT directly to S3 (or stub URL in dev)
        if (!presignedUrl.startsWith("/dev/")) {
          await fetch(presignedUrl, {
            method: "PUT",
            body: newUploads[i].file,
            headers: { "Content-Type": newUploads[i].file.type || "image/jpeg" },
          });
        }

        // Step 3: confirm
        setStatus("confirming");
        const confirmRes = await apiFetch<{ data: InspectionPhoto }>(
          `/api/v1/inspections/${inspectionId}/photos/${photoId}/confirm`,
          { method: "PATCH" },
        );

        setStatus("done");
        onUploaded(confirmRes.data);
      } catch (err) {
        const msg = err instanceof ApiError ? err.message : "Upload failed";
        setStatus("error", { error: msg });
      }
    }
  }

  return (
    <div className="flex flex-col gap-4">
      {/* Uploaded photos grid */}
      {uploadedPhotos.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {uploadedPhotos.map((photo) => (
            <div
              key={photo.id}
              className="flex items-center gap-1.5 rounded-md border border-border bg-card px-3 py-2 text-sm"
            >
              <CheckCircle2 className="h-3.5 w-3.5 text-green-500 shrink-0" />
              <span className="max-w-[160px] truncate text-muted-foreground">
                {photo.filename ?? photo.s3_key.split("/").pop()}
              </span>
            </div>
          ))}
        </div>
      )}

      {/* In-flight uploads */}
      {pending.length > 0 && (
        <div className="flex flex-col gap-1">
          {pending.map((u, i) => (
            <PendingRow key={i} upload={u} />
          ))}
        </div>
      )}

      {/* Pick files button */}
      {!disabled && (
        <>
          <input
            ref={inputRef}
            type="file"
            accept="image/*"
            multiple
            className="hidden"
            aria-label="Upload inspection photos"
            onChange={(e) => handleFiles(e.target.files)}
          />
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="self-start"
            onClick={() => inputRef.current?.click()}
          >
            <Camera className="mr-2 h-4 w-4" />
            Add photo{uploadedPhotos.length > 0 ? "s" : ""}
          </Button>
        </>
      )}
    </div>
  );
}

function PendingRow({ upload }: { upload: PendingUpload }) {
  const label = {
    idle: "Waiting…",
    requesting: "Preparing…",
    uploading: "Uploading…",
    confirming: "Confirming…",
    done: "Done",
    error: upload.error ?? "Error",
  }[upload.status];

  return (
    <div
      className={cn(
        "flex items-center gap-2 text-sm text-muted-foreground",
        upload.status === "error" && "text-destructive",
      )}
    >
      {upload.status === "done" ? (
        <CheckCircle2 className="h-3.5 w-3.5 text-green-500" />
      ) : upload.status === "error" ? (
        <X className="h-3.5 w-3.5 text-destructive" />
      ) : (
        <Loader2 className="h-3.5 w-3.5 animate-spin" />
      )}
      <span className="truncate max-w-[200px]">{upload.file.name}</span>
      <span className="shrink-0 text-xs">· {label}</span>
    </div>
  );
}
