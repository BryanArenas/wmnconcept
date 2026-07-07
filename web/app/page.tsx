import { redirect } from "next/navigation";
import { getCurrentUser, homePathForRole } from "@/lib/auth";

// Entry point: send signed-in users to their surface home, everyone else to the
// login page. The public marketing site stays on the current CMS at MVP (§10).
export default async function RootPage() {
  const user = await getCurrentUser();
  redirect(user ? homePathForRole(user.role) : "/login");
}
