// Typed fetch client for the Rails API. Isomorphic: on the client it rides the
// browser session cookie and attaches the CSRF header on mutations; on the
// server, callers pass the forwarded session cookie via `headers` (see
// lib/auth.ts). Every non-2xx is unwrapped from the `{ error: {...} }` envelope
// (spec §4) into a typed ApiError.

export const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:3001";

export interface ApiErrorDetail {
  field?: string;
  message: string;
}

export interface ApiErrorEnvelope {
  code: string;
  message: string;
  details: ApiErrorDetail[];
}

export class ApiError extends Error {
  readonly code: string;
  readonly status: number;
  readonly details: ApiErrorDetail[];

  constructor(status: number, envelope: ApiErrorEnvelope) {
    super(envelope.message);
    this.name = "ApiError";
    this.status = status;
    this.code = envelope.code;
    this.details = envelope.details ?? [];
  }

  // Field-keyed errors for react-hook-form (spec §10). Detail entries without a
  // field are dropped here and surfaced as a toast by the caller.
  fieldErrors(): Record<string, string> {
    return this.details.reduce<Record<string, string>>((acc, d) => {
      if (d.field) acc[d.field] = d.message;
      return acc;
    }, {});
  }
}

const UNSAFE_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

export async function apiFetch<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const method = (options.method ?? "GET").toUpperCase();
  const headers = new Headers(options.headers);

  if (options.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  // Client-side CSRF: echo the XSRF-TOKEN cookie back as a header on mutations.
  if (typeof document !== "undefined" && UNSAFE_METHODS.has(method)) {
    const token = readCookie("XSRF-TOKEN");
    if (token) headers.set("X-CSRF-Token", token);
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    method,
    headers,
    credentials: "include",
  });

  if (response.status === 204) {
    return undefined as T;
  }

  const body = await response.json().catch(() => null);

  if (!response.ok) {
    const envelope: ApiErrorEnvelope = body?.error ?? {
      code: "unknown_error",
      message: response.statusText || "Request failed",
      details: [],
    };
    throw new ApiError(response.status, envelope);
  }

  return body as T;
}

function readCookie(name: string): string | null {
  const match = document.cookie.match(
    new RegExp(`(?:^|; )${name.replace(/([.$?*|{}()[\]\\/+^])/g, "\\$1")}=([^;]*)`),
  );
  return match ? decodeURIComponent(match[1]) : null;
}
