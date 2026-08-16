# Idea — "Compete": a link-in, try-on-out outfit battle app

**Hackathon:** [YouCam API Skin AI & Apparel VTO Hackathon](https://youcam-api.devpost.com/)
**Deadline:** Aug 17, 2026 @ 11:45am EDT
**Status:** idea exploration — nothing locked yet

---

## The one-liner

You're scrolling anywhere — Instagram, TikTok, Pinterest, a Zara product page. You see a
piece you like. You hit **Share → Compete**. We pull the garment out of that link, put it on
*your* body with YouCam Apparel VTO, and let you build a full outfit from pieces you've
collected. Post the outfit. The community votes. The most-liked look becomes **Outfit of
the Day**.

The share sheet is the whole onboarding. No catalog to browse, no store to sign up for.
The internet is already the catalog.

---

## Why this shape

Every virtual try-on demo today is bolted to one retailer's inventory. You try on their
shirt, on their site, in their app. But nobody dresses from one store. People build looks
from a screenshot of a friend, a TikTok fit check, and a product page they'll never buy from.

Two things make this work as a product rather than a toy:

1. **Ingest is the moat.** A share-sheet target that accepts *any* link is a much lower-friction
   entry point than "browse our catalog." It's how Pinterest won.
2. **Try-on is the payoff, not the feature.** You don't see the garment on a model. You see
   it on you. That's the thing worth posting.

---

## Core loop

```
   see something anywhere
            │
            ▼
   share link → Compete          ← the hook
            │
            ▼
   extract garment from page     ← OG image / product image scrape
            │
            ▼
   YouCam Apparel VTO on your photo   ← the payoff
            │
            ▼
   collect pieces into a Closet
            │
            ▼
   pair them → outfit variants   ← "version A vs version B"
            │
            ▼
   post the look
            │
            ▼
   community likes → Outfit of the Day   ← the reason to come back
```

---

## Feature sketch

### 1. Share-sheet ingest
Register as an iOS/Android share target. User shares any URL. We fetch the page, pull the
primary product/garment image (OpenGraph `og:image`, JSON-LD `Product.image`, or largest
image heuristic), and save it to their Closet as a garment card.

*Fallback for the demo:* paste-a-link field + a few seeded garments, in case a given site
blocks scraping on stage.

### 2. Try it on
Take/upload one full-body photo once — that's your model shot. Every garment you add gets
rendered onto it via YouCam Apparel VTO. Your Closet isn't a grid of product photos, it's a
grid of *you* wearing things.

### 3. Pair + version
Pick a top, a bottom, outerwear, and the app composes the full look. Make several versions
of the same base — swap the jacket, swap the shoes — and hold them side by side. This is
where the "compete" name earns itself: you compete with yourself first.

### 4. Post + vote
Publish a look to a shared feed. One tap to like. Simple, honest ranking.

### 5. Outfit of the Day
Daily window, most-liked look wins, gets a badge and a spot at the top of the feed. Resets
every 24h so the feed always has a fresh reason to open.

---

## Where YouCam APIs fit

| Surface | API | Why it's non-trivial |
|---|---|---|
| Wear any garment from any link | **Apparel VTO** | Core of the product, not decoration |
| Skin-tone-aware palette suggestions | **Skin AI** | "This olive works with your undertone" — turns a beauty API into a styling signal |
| Clean up user model photos | Image editing | Background removal so looks read consistently in the feed |

The Skin AI angle is the one that makes this feel like *this* hackathon rather than a
generic try-on app: the judging criterion is "creative, non-obvious API use," and using
skin analysis as a **fashion color-matching input** is a genuine cross-over rather than
two features sitting next to each other.

---

## How this maps to the judging criteria

- **Technological Implementation** — link extraction → VTO pipeline is real integration work, not a button that calls one endpoint.
- **Design** — the share-sheet-to-feed loop is a complete product story, start to finish.
- **Potential Impact** — reduces returns (you saw it on your body), and gives retailers a discovery channel they don't own.
- **Quality of Idea** — VTO decoupled from any single retailer's catalog, plus skin-tone-driven color advice.

---

## Open questions

- Does Apparel VTO accept an arbitrary garment image, or does it need a structured
  garment/category input? **This determines whether the link-ingest premise is even
  possible.** Verify before building anything else.
- Are garments categorized (top / bottom / full-body / outerwear) and can we layer multiple
  pieces into one render, or do we composite client-side?
- Latency per try-on render — does this feel instant enough for a scroll-and-tap loop, or
  do we need an optimistic "rendering…" state?
- Scraping reliability across major fashion sites.

---

## Honest scoping note

With ~24 hours to the deadline, the full loop above is a product vision, not a build plan.
The demo-critical path is:

**link in → garment extracted → VTO render on user photo → two variants side by side → post → likeable feed**

Everything else (Skin AI palette, background cleanup, daily reset job, auth, profiles) is
cut-first material. See `docs/plan.md` when it exists.
