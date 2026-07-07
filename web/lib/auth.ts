import "server-only";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { apiFetch, ApiError } from "./api";
import type { Role, Surface, User } from "./types";

// Server-side session helpers. Server Components forward the incoming HTTPOnly
// session cookie to GET /me to establish identity, then role-gate layouts as
// defense-in-depth on top of Pundit (spec §10).

export async function getCurrentUser(): Promise<User | null> {
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();

  try {
    const { data } = await apiFetch<{ data: User }>("/api/v1/me", {
      headers: { cookie: cookieHeader },
      cache: "no-store",
    });
    return data;
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) return null;
    // A down API or unexpected error is treated as "not signed in" for gating;
    // the login page is the safe destination.
    return null;
  }
}

// The app shell a role belongs to. Staff roles share the staff surface;
// inspectors get the field surface.
export function surfaceForRole(role: Role): Surface {
  return role === "inspector" ? "field" : "staff";
}

export async function requireUser(): Promise<User> {
  const user = await getCurrentUser();
  if (!user) redirect("/login");
  return user;
}

// Assert the signed-in user's role is allowed on this surface; otherwise send
// them to their own home rather than leaking a mismatched shell.
export async function requireRole(...roles: Role[]): Promise<User> {
  const user = await requireUser();
  if (!roles.includes(user.role)) {
    redirect(homePathForRole(user.role));
  }
  return user;
}

export function homePathForRole(role: Role): string {
  return role === "inspector" ? "/today" : "/dashboard";
}
