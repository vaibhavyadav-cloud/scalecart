/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        // A small brand palette, defined once here rather than inline
        // hex codes scattered through every component - see
        // docs/04-docker-optimization.md's "platform contract" idea
        // applied to the frontend's own design system.
        brand: {
          50: "#f2f6ff",
          100: "#e0e9ff",
          200: "#c2d2ff",
          300: "#96afff",
          400: "#6483ff",
          500: "#3d5aff",
          600: "#2338f0",
          700: "#1c2bc4",
          800: "#1b269c",
          900: "#1b267c",
        },
        ink: {
          50: "#f7f8fa",
          100: "#eceef2",
          200: "#d5d9e2",
          300: "#b1b8c9",
          400: "#8790a8",
          500: "#67708c",
          600: "#515873",
          700: "#41475e",
          800: "#2c3040",
          900: "#181a24",
        },
      },
      fontFamily: {
        // var(--font-inter) is set by next/font in layout.tsx - self-hosted,
        // no external request, works from a static export.
        sans: ["var(--font-inter)", "ui-sans-serif", "system-ui", "sans-serif"],
      },
      boxShadow: {
        card: "0 1px 2px rgba(24,26,36,0.06), 0 1px 12px rgba(24,26,36,0.04)",
      },
    },
  },
  plugins: [],
};
