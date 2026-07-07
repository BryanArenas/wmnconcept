"use client";

import { ErrorPanel } from "@/components/domain/error-panel";

export default function AgencyError({
  error,
  unstable_retry,
}: {
  error: Error & { digest?: string };
  unstable_retry: () => void;
}) {
  return <ErrorPanel error={error} retry={unstable_retry} />;
}
