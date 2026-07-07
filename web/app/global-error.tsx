"use client";

export default function GlobalError({
  error,
  unstable_retry,
}: {
  error: Error & { digest?: string };
  unstable_retry: () => void;
}) {
  return (
    <html lang="en">
      <body
        style={{
          fontFamily: "system-ui, sans-serif",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          minHeight: "100dvh",
          margin: 0,
          backgroundColor: "#fff",
          color: "#0a0a0a",
        }}
      >
        <div style={{ textAlign: "center", maxWidth: 420, padding: 24 }}>
          <h1 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
            Something went wrong
          </h1>
          <p style={{ fontSize: 14, color: "#57534e", marginBottom: 16 }}>
            An unexpected error occurred. Try refreshing the page.
          </p>
          {error.digest && (
            <p
              style={{
                fontSize: 11,
                color: "#a8a29e",
                fontFamily: "monospace",
                marginBottom: 16,
              }}
            >
              {error.digest}
            </p>
          )}
          <button
            onClick={unstable_retry}
            style={{
              padding: "8px 16px",
              fontSize: 14,
              border: "1px solid #e7e5e4",
              borderRadius: 8,
              background: "transparent",
              cursor: "pointer",
            }}
          >
            Try again
          </button>
        </div>
      </body>
    </html>
  );
}
