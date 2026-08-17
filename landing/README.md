# fitcheck Next.js landing page

The landing page is a standalone Next.js App Router project, kept separate from
the Flutter web bootstrap.

## Preview locally

From this directory, run:

```sh
npm install
npm run dev
```

Then open `http://localhost:3000`.

Create a production build with `npm run build` and serve it with `npm start`.

## Fonts

DM Sans and the editorial fallback are self-hosted by `next/font`. The heading
stack uses Eighties Comeback when that licensed typeface is available locally.
See `public/fonts/README.md` to bundle the licensed webfont for deployment.
