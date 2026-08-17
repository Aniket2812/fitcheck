# Eighties Comeback

The landing page is wired for the licensed **Eighties Comeback** display face.

Place the licensed webfont at:

`landing/public/fonts/EightiesComeback-Regular.woff2`

Then add this source to the `@font-face` rule in `landing/app/globals.css`:

`url("/fonts/EightiesComeback-Regular.woff2") format("woff2")`

Until that licensed file is supplied, the page uses Cormorant Garamond as a
close high-contrast editorial fallback. Both Cormorant Garamond and DM Sans are
optimized and self-hosted by Next.js through `next/font`.
