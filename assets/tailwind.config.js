// Tailwind scans only the dashboard's own templates — never the host app — so
// the JIT output stays small and can't bleed host classes into the bundle.
module.exports = {
  content: ["../lib/**/*.{ex,heex}"],
  theme: {
    extend: {
      colors: {
        bloccs: {
          bg: "#09090b",
          surface: "#1a1326",
          purple: "#7c37ab",
          accent: "#c98bff",
          text: "#fafafa",
        },
      },
    },
  },
  plugins: [],
}
