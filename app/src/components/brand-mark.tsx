import { cn } from "@/lib/cn";

/** Findmeajob's logo, the shield from public/logo.png (also src/app/icon.png). Decorative: put the name next to it. */
export function BrandMark({ className }: { className?: string }) {
  return (
    // A plain <img>: the logo is a fixed local file, and next/image would only add work.
    // eslint-disable-next-line @next/next/no-img-element
    <img src="/logo.png" alt="" aria-hidden="true" className={cn("size-8 shrink-0 rounded-[22%] object-cover", className)} />
  );
}
