// `color` is a separate prop from `className` deliberately - stuffing an
// override like "text-white" into className alongside the default
// "text-brand-600" relies on which utility rule happens to come later in
// Tailwind's generated stylesheet (NOT JSX order), which is undefined
// from the caller's point of view. A dedicated prop makes "what color is
// this spinner" a single, unambiguous JS value instead of a CSS
// specificity race.
export function Spinner({
  className = "h-5 w-5",
  color = "text-brand-600",
}: {
  className?: string;
  color?: string;
}) {
  return (
    <svg
      className={`animate-spin ${color} ${className}`}
      viewBox="0 0 24 24"
      fill="none"
      aria-label="Loading"
      role="status"
    >
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
    </svg>
  );
}
