import type { Metadata } from "next";
import { Inter, Fraunces } from "next/font/google";
import { GeistMono } from "geist/font/mono";
import "./globals.css";

// UI / body (§5.2). Self-hosted by next/font — no layout shift.
const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

// Display serif for page titles + large stat numbers (§5.2).
const fraunces = Fraunces({
  variable: "--font-fraunces",
  subsets: ["latin"],
  display: "swap",
  axes: ["opsz"],
});

export const metadata: Metadata = {
  title: "WINDMITIGATION.NETWORK — Inspection Operations",
  description:
    "Third-party wind-mitigation inspection operations for Wind Mitigation Network.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="en"
      className={`${inter.variable} ${fraunces.variable} ${GeistMono.variable}`}
    >
      <body>
        <a
          href="#main-content"
          className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-background focus:px-4 focus:py-2 focus:text-sm focus:font-medium focus:text-foreground focus:shadow-lg focus:ring-2 focus:ring-ring"
        >
          Skip to content
        </a>
        {children}
      </body>
    </html>
  );
}
