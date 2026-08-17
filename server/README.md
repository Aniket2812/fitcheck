# fitcheck backend

Hono service that turns a product link into a background-free garment cutout.
The API key lives here and never ships in the app bundle.

## Run

```bash
cd server
npm install
# add your key to .env
npm run dev
```

Listens on `0.0.0.0:8787` so a phone on the same Wi-Fi can reach it.

## Configure

| Variable | Purpose |
|---|---|
| `OPENAI_API_KEY` | Required. Used for product research, metadata, and cutouts. |
| `OPENAI_RESEARCH_MODEL` | OpenAI model for product-link research. Defaults to `gpt-5.6-sol`. |
| `OPENAI_RESEARCH_TIMEOUT_MS` | Product research limit. Defaults to 100 seconds. |
| `YOUCAM_API_KEY` | Perfect Corp API key used as the v2 bearer token for AI Clothes v3. |
| `YOUCAM_SECRET_KEY` | Account secret retained server-side; never sent to the app. |
| `YOUCAM_TIMEOUT_MS` | Maximum Clothes task time; defaults to 180 seconds. |
| `PORT` | Defaults to `8787`. |
| `GOOGLE_CLIENT_ID` | OAuth client id(s) allowed as an ID token audience, comma-separated. Unset = dev sign-ins only. |
| `DATA_FILE` | Where accounts and sessions are stored. Defaults to `server/data/users.json`. |
| `MEDIA_DIR` | Persistent outfit/cutout upload directory. Defaults to `server/data/media`. |
| `SEED_DEMO_DATA` | Seeds the versioned starter feed on first run. Defaults to enabled; set to `false` for production. |

`.env` is gitignored. `.env.example` is the template.

## Endpoints

### `GET /health`
`{ ok, provider, hasKey, productResearch, sites }` — quick check that the keys are
actually loaded and how many retailers have tuned rules.

### `GET /api/sites`
`{ sites: [{ host, label }] }` — the retailers with per-host rules, for a
"works with…" list in the app.

### `POST /api/ingest`
```json
{ "url": "Loved this https://www.zara.com/...?utm_source=ig" }
```
`url` takes a raw paste, not just a clean URL — share text, a shortener
(`a.co`, `bit.ly`, `*.onelink.me`), or an Android `intent://` deep link all
resolve. Tracking params are stripped; variant params (`?v1=`, `?colourwayid=`)
are kept, since they pick the colour.
Returns:
```json
{
  "id": "item-1755...",
  "title": "Men Black Solid Round Neck T-shirt",
  "brand": "Roadster",
  "price": "INR 499",
  "image": "data:image/webp;base64,...",
  "originalImage": "https://...",
  "pageUrl": "https://...",
  "extractedVia": "json-ld"
}
```

## Accounts

Google is the only identity provider — there is no email/password path and no
separate sign-up step, because Google has already told us who this is.

The client runs the OAuth flow and posts the resulting **ID token** here. The
server proves it came from Google (`src/google.js` → Google's `tokeninfo`
endpoint, plus its own audience and issuer checks), then creates or finds the
matching account and issues an opaque **session token**. Everything after that
is `Authorization: Bearer <token>`.

Users and sessions live in one JSON file (`src/store.js`). That is a
hackathon-shaped decision: the working set fits in memory, and the module's
surface is the one a real repository would have, so moving to Postgres later
means rewriting that file and nothing else.

### `POST /api/auth/google`
```json
{ "idToken": "<Google ID token>" }
```
Returns `{ token, expiresAt, user }`. Sessions last 90 days.

Until `GOOGLE_CLIENT_ID` is set the server has no way to verify a real token,
so it accepts a dev stand-in of the form `dev:<id>:<email>:<name>` instead —
letting profiles be built and demoed before OAuth is wired up. Setting the
client id turns that path off automatically; there is no flag to forget.

### `POST /api/auth/signout`
Bearer-authenticated. Drops this device's session only.

### `GET /api/me` · `PATCH /api/me`
Bearer-authenticated. `PATCH` accepts any of `name`, `handle`, `bio`,
`avatarUrl`, `modelPhotoUrl`. Handles are `[a-z0-9_]{3,20}` and unique;
a clash returns `409`.

### `GET /api/users/:handle`
Public profile. Email and model photo are never in this projection.

## Reusable full-body photos

- `GET /api/model-photos` — lists the signed-in user's saved photos.
- `POST /api/model-photos` — uploads multipart field `image`; the first upload
  becomes the default.
- `POST /api/model-photos/:id/primary` — changes the default try-on photo.
- `DELETE /api/model-photos/:id` — removes the photo from future selection.

Each account can keep up to 12 photos. Only the signed-in owner can list or
mutate their records. The bundled local server uses unguessable media names;
production deployments should serve model photos from private object storage
through short-lived signed URLs.

## Social feed

Posts are persisted beside accounts and sessions; uploaded images and garment
cutouts are stored under `server/data/media` and served from immutable
`/media/:name` URLs.

On first startup, the server imports 14 starter posts from the versioned
fixture in `seed/feed.json` into the same persistent store. The app receives
them exclusively from `GET /api/posts`; there is no client-side fallback or
hardcoded feed. Stable
seed IDs prevent duplicate users or posts after restarts. Set
`SEED_DEMO_DATA=false` to start with an empty feed instead.

The bundled demo outfits and product previews are cropped from the same source
boards, so each hotspot opens the item shown in the post. Every `buyUrl` is a
direct retailer product page rather than a category or search-results link.
`seed/visual-matches.json` records the audited colour and product identity for
every tag; `npm run test:feed` fails if either side is remapped independently.

- `GET /api/posts` — newest-first feed; bearer auth is optional and adds
  `likedByMe`.
- `POST /api/posts` — bearer-authenticated multipart upload (`image`, `caption`,
  `garments` JSON) or JSON with an existing server `imageUrl`.
- `GET /api/posts/:id` — post, author, tagged garments, likes, and comments.
- `POST /api/posts/:id/like` — toggles the current user's like.
- `POST /api/posts/:id/comments` — adds `{ "text": "..." }`.
- `DELETE /api/posts/:id` — owner-only deletion.

Garment coordinates are normalized `x`/`y` values. The client renders them as
hotspots over the outfit; opening one displays the already extracted transparent
product asset and its original buying link.

## YouCam virtual try-on

`POST /api/try-on` accepts a bearer-authenticated multipart body with `photo`,
`garmentUrl`, and `category` (`upper_body`, `lower_body`, or `full_body`). The
server performs Perfect Corp's complete File API → signed upload → Clothes task
→ polling workflow, downloads the temporary result, and stores it under a stable
local media URL before returning it. `GET /api/try-on/config` lets the app hide
the action when no key is configured.

`POST /api/try-on/model` accepts JSON with `modelPhotoId`, `garmentUrl`, and
`category`, loads the authenticated user's stored photo server-side, and
returns the stable generated preview URL. Clothes use AI Clothes v3; products
classified as shoes use the dedicated AI Shoes workflow. Other accessories
remain shoppable/taggable but require their matching YouCam accessory engine.

The client passes the product image URL extracted from the retailer page as
YouCam's reference image. Retailer webpage URLs are never sent directly to the
try-on task.

## How ingestion works

Four stages, each falling back only when the cheaper one fails.

**1. Normalise the link** (`links.js`) — pull the URL out of share text, follow
shorteners, drop tracking params.

**2. Fetch or research the product** — `fetchPage.js` first makes a plain fetch
shaped like a real Chrome navigation. If the retailer rejects that request,
returns a bot challenge, times out, or serves an empty app shell, `extract.js`
uses the OpenAI Responses API with built-in web search to identify the exact
product and direct product-photo URLs. OpenAI never substitutes a similar item;
uncertain results fail cleanly.

**3. Find the product** (`extract.js`), in reliability order:

1. **JSON-LD `Product`** — walks `@graph` / `hasVariant` / nested nodes. Parsed
   leniently: a raw newline inside a string (a pasted customer review) makes
   `JSON.parse` reject the whole block, and that alone was costing us Myntra.
2. **Microdata** — `itemtype="schema.org/Product"`, common on Shopify themes.
3. **Embedded app state** — `__NEXT_DATA__`, `__NUXT__`, `__INITIAL_STATE__`.
   Scores every object in the blob and keeps the most product-shaped one, which
   is how the React storefronts (adidas, most SPAs) resolve.
4. **OpenGraph / Twitter meta** — `og:image`, `og:title`.
5. **Largest declared `<img>`** — last resort, srcset-aware, ≥300px wide.

The winning image URL then gets a per-retailer rewrite (`sites.js`) that swaps
the CDN's thumbnail token for a full-size one — cutout quality tracks input
resolution closely, and `og:image` is often a 400px crop. The original is kept
as a fallback in case the rewrite 404s.

`gpt-4o-mini` is only called for missing metadata. The more capable product
research model runs only when direct fetching or parsing fails, so structured
retailer pages incur no research call.

**4. Cut it out** — the image is downloaded (with a `referer`, or the CDNs
reject the hotlink) and sent to `images.edit` (`gpt-image-1`) with
`background: "transparent"`.

## Retailer coverage

`sites.js` carries per-host rules for ~50 retailers, global and Indian. A host
that is not in that table still works — it just gets the generic path.

Confirmed extracting over a plain fetch: **Myntra,
Bewakoof, Westside, Libas, Flipkart, Uniqlo, J.Crew, Madewell, Nike, Levi's.**
Myntra in particular returns full JSON-LD — title, brand, price and a 1080px
image — to an ordinary server fetch.

AJIO is the notable gap: its PDP is rendered from `window.__PRELOADED_STATE__`,
which the extractor reads, but its category pages and internal API sit behind
Akamai, so no live product code was available to confirm it end to end. A
shared AJIO product link should work; it is untested.

```bash
npm run coverage              # pass/fail table, one row per retailer
npm run coverage -- zara nike # filter by host
npm run coverage -- --research zara # also exercise paid OpenAI fallback
npm run test:research         # one exact-product OpenAI integration check
```

The table marks rows whose sample URL has not been confirmed live, since a dead
product link and a broken parser otherwise look identical. Only the confirmed
rows gate the exit code.

## Known limits

- **Bot-protected shops require an OpenAI research call.** Amazon, Zara, H&M,
  ASOS, SHEIN, Nordstrom and similar retailers may refuse direct server fetches.
  Those imports cost more and take longer than deterministic parsing.
- **Sample product URLs rot.** Items sell out and 404. Replace the URL in
  `test/urls.js` rather than reading a regression into it.
- **Some retailers rate-limit rather than block.** adidas can parse directly
  and then start refusing the same server IP; the same OpenAI fallback handles
  that case.
- **The cutout is generative**, so it can subtly redraw fabric detail. For a
  shopping decision that matters — worth comparing against `originalImage`.
- **Cutouts return as base64 data URLs.** Fine for a demo; move to object
  storage before this holds many items, since they sit in memory.

## Provider responsibilities

OpenAI creates the transparent product cutout used by garment hotspots. YouCam
AI Clothes v3 or AI Shoes combines a saved user photo with the product
reference to generate the virtual-try-on look. They are separate stages because
the YouCam try-on APIs are not background-removal APIs.
