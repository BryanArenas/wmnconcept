import Link from "next/link";

export default function NotFound() {
  return (
    <div className="flex min-h-dvh items-center justify-center bg-background px-5">
      <div className="flex flex-col items-center gap-4 text-center">
        <p className="font-serif text-stat text-muted-foreground/30">404</p>
        <p className="text-title text-foreground">Page not found</p>
        <p className="max-w-[38ch] text-body text-muted-foreground">
          The page you are looking for does not exist or has been moved.
        </p>
        <Link
          href="/"
          className="mt-2 inline-flex h-9 items-center rounded-md border border-border bg-background px-4 text-body font-medium transition-colors hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-1"
        >
          Go home
        </Link>
      </div>
    </div>
  );
}
