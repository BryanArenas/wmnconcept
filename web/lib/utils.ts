import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

// Standard shadcn class combiner: clsx for conditionals, tailwind-merge to
// dedupe conflicting utilities.
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
