import * as cheerio from 'cheerio';

import { hostOf, isShortener, cleanUrl } from './links.js';
import { loadPage, resolveRedirect } from './fetchPage.js';
import { upgradeImage, siteFor } from './sites.js';

const absolute = (src, base) => {
  if (!src) return null;
  try {
    const url = new URL(String(src).trim(), base);
    return url.protocol === 'http:' || url.protocol === 'https:' ? url.href : null;
  } catch {
    return null;
  }
};

const clean = (value) => {
  if (value == null) return null;
  const text = String(value).replace(/\s+/g, ' ').trim();
  return text && text.length < 300 ? text : null;
};

/** Retailers write prices as "1,299.00", "$34", "34.00 USD" — keep the number. */
function formatPrice(amount, currency) {
  if (amount == null) return null;
  const raw = String(amount).replace(/[^\d.,]/g, '');
  if (!raw) return null;
  return clean(`${currency || ''} ${raw}`.trim());
}

/* -------------------------------------------------------------------------- */
/* JSON-LD                                                                     */
/* -------------------------------------------------------------------------- */

/**
 * Retailers ship malformed LD-JSON constantly, and the most common fault by far
 * is a raw newline or tab inside a string literal — a customer review pasted in
 * verbatim. `JSON.parse` rejects the whole block for it, which on Myntra meant
 * silently falling back to a 200x200 og:image thumbnail.
 *
 * Replacing control characters with a space fixes those without changing valid
 * documents: between tokens they are whitespace already, and escaped `\n` is a
 * two-character sequence this never touches.
 */
function parseJsonLoose(text) {
  try {
    return JSON.parse(text);
  } catch {
    try {
      return JSON.parse(text.replace(/[\u0000-\u001F]/g, ' '));
    } catch {
      return null;
    }
  }
}

const typesOf = (node) => {
  const type = node?.['@type'];
  return (Array.isArray(type) ? type : [type]).filter(Boolean).map(String);
};

/** Walks JSON-LD looking for a Product node, however deeply it is nested. */
function findProduct(node, depth = 0) {
  if (!node || typeof node !== 'object' || depth > 8) return null;
  if (Array.isArray(node)) {
    for (const child of node) {
      const hit = findProduct(child, depth + 1);
      if (hit) return hit;
    }
    return null;
  }
  if (typesOf(node).some((t) => t === 'Product' || t === 'ProductGroup' || t === 'Clothing')) {
    return node;
  }
  for (const key of ['@graph', 'itemListElement', 'mainEntity', 'item', 'hasVariant', 'about']) {
    if (node[key]) {
      const hit = findProduct(node[key], depth + 1);
      if (hit) return hit;
    }
  }
  return null;
}

function firstImage(image) {
  if (!image) return null;
  if (Array.isArray(image)) return firstImage(image[0]);
  if (typeof image === 'string') return image;
  return image.url || image.contentUrl || null;
}

function priceFromOffers(offers) {
  if (!offers) return null;
  const offer = Array.isArray(offers) ? offers[0] : offers;
  if (!offer) return null;
  const amount =
    offer.price ??
    offer.lowPrice ??
    offer.highPrice ??
    offer.priceSpecification?.price ??
    (Array.isArray(offer.priceSpecification) ? offer.priceSpecification[0]?.price : null);
  const currency =
    offer.priceCurrency ||
    offer.priceSpecification?.priceCurrency ||
    (Array.isArray(offer.priceSpecification) ? offer.priceSpecification[0]?.priceCurrency : null);
  return formatPrice(amount, currency);
}

function brandName(brand) {
  if (!brand) return null;
  if (Array.isArray(brand)) return brandName(brand[0]);
  if (typeof brand === 'string') return clean(brand);
  return clean(brand.name);
}

function fromJsonLd($, base) {
  for (const el of $('script[type="application/ld+json"]').toArray()) {
    const parsed = parseJsonLoose($(el).contents().text());
    if (!parsed) continue;

    const product = findProduct(parsed);
    if (!product) continue;

    const imageUrl = absolute(firstImage(product.image), base);
    if (!imageUrl) continue;

    return {
      title: clean(product.name),
      brand: brandName(product.brand),
      price: priceFromOffers(product.offers),
      imageUrl,
      source: 'json-ld',
    };
  }
  return null;
}

/* -------------------------------------------------------------------------- */
/* Microdata                                                                   */
/* -------------------------------------------------------------------------- */

/** schema.org in attributes rather than a script block — older stacks, Shopify themes. */
function fromMicrodata($, base) {
  const scope = $('[itemtype*="schema.org/Product"]').first();
  if (!scope.length) return null;

  const prop = (name) => scope.find(`[itemprop="${name}"]`).first();
  const value = (name) => {
    const el = prop(name);
    if (!el.length) return null;
    return clean(el.attr('content') || el.attr('href') || el.text());
  };

  const imageEl = prop('image');
  const imageUrl = absolute(
    imageEl.attr('content') || imageEl.attr('src') || imageEl.attr('href'),
    base,
  );
  if (!imageUrl) return null;

  return {
    title: value('name'),
    brand: value('brand'),
    price: formatPrice(
      prop('price').attr('content') || prop('price').text(),
      value('priceCurrency'),
    ),
    imageUrl,
    source: 'microdata',
  };
}

/* -------------------------------------------------------------------------- */
/* Embedded app state                                                          */
/* -------------------------------------------------------------------------- */

const STATE_SELECTORS = [
  'script#__NEXT_DATA__',
  'script#__NUXT_DATA__',
  'script[type="application/json"][data-product]',
  'script[id*="product"][type="application/json"]',
];

// `__myx` is Myntra's; the rest are the usual framework globals.
const STATE_GLOBALS =
  /(?:window\.)?(?:__INITIAL_STATE__|__PRELOADED_STATE__|__APOLLO_STATE__|__NUXT__|__STATE__|__myx|dataLayer)\s*=\s*/;

const NAME_KEYS = ['name', 'productName', 'title', 'displayName', 'productTitle'];
const IMAGE_KEYS = ['image', 'imageUrl', 'images', 'media', 'mainImage', 'primaryImage', 'src'];
const PRICE_KEYS = ['price', 'currentPrice', 'salePrice', 'listPrice', 'finalPrice', 'value'];
const BRAND_KEYS = ['brand', 'brandName', 'designer', 'vendor', 'manufacturer'];

const pick = (node, keys) => {
  for (const key of keys) {
    if (node[key] != null) return node[key];
  }
  return null;
};

function imageFromValue(value, depth = 0) {
  if (value == null || depth > 3) return null;
  if (typeof value === 'string') return /^(https?:)?\/\/|^\//.test(value) ? value : null;
  if (Array.isArray(value)) {
    for (const item of value) {
      const hit = imageFromValue(item, depth + 1);
      if (hit) return hit;
    }
    return null;
  }
  if (typeof value === 'object') {
    return imageFromValue(pick(value, ['url', 'src', 'imageUrl', 'href', 'large', 'zoom']), depth + 1);
  }
  return null;
}

/**
 * Scores every object in a state blob and keeps the best product-shaped one.
 * Deliberately loose: SPAs name these fields a dozen different ways, and a
 * wrong guess costs one LLM fallback, not a wrong item.
 */
function scoreNode(node) {
  const name = clean(pick(node, NAME_KEYS));
  const image = imageFromValue(pick(node, IMAGE_KEYS));
  if (!name || !image) return null;
  const price = pick(node, PRICE_KEYS);
  return {
    score: 1 + (price != null ? 1 : 0) + (pick(node, BRAND_KEYS) != null ? 1 : 0),
    candidate: {
      title: name,
      brand: brandName(pick(node, BRAND_KEYS)),
      price: formatPrice(typeof price === 'object' ? pick(price ?? {}, PRICE_KEYS) : price, null),
      imageUrl: image,
    },
  };
}

function walkForProduct(root) {
  let best = null;
  const stack = [[root, 0]];
  let visited = 0;

  while (stack.length && visited < 20_000) {
    const [node, depth] = stack.pop();
    visited += 1;
    if (!node || typeof node !== 'object' || depth > 12) continue;

    if (!Array.isArray(node)) {
      const scored = scoreNode(node);
      if (scored && (!best || scored.score > best.score)) best = scored;
      if (best?.score === 3) break; // name + image + price + brand; good enough.
    }

    for (const value of Object.values(node)) {
      if (value && typeof value === 'object') stack.push([value, depth + 1]);
    }
  }

  return best?.candidate || null;
}

function fromEmbeddedState($, base) {
  const blobs = [];

  for (const selector of STATE_SELECTORS) {
    for (const el of $(selector).toArray()) {
      blobs.push($(el).contents().text());
    }
  }

  for (const el of $('script:not([src])').toArray()) {
    const text = $(el).contents().text();
    if (text.length > 400_000) continue; // Bundles, not state.
    const match = text.match(STATE_GLOBALS);
    if (!match) continue;
    const start = text.indexOf('{', match.index + match[0].length - 1);
    if (start === -1) continue;
    blobs.push(text.slice(start).replace(/;?\s*$/, '').replace(/<\/script>[\s\S]*$/, ''));
  }

  for (const blob of blobs) {
    let parsed;
    try {
      parsed = JSON.parse(blob);
    } catch {
      // Trailing statements after the object are common; retry at the last brace.
      const end = blob.lastIndexOf('}');
      if (end === -1) continue;
      try {
        parsed = JSON.parse(blob.slice(0, end + 1));
      } catch {
        continue;
      }
    }

    const found = walkForProduct(parsed);
    const imageUrl = absolute(found?.imageUrl, base);
    if (imageUrl) return { ...found, imageUrl, source: 'app-state' };
  }

  return null;
}

/* -------------------------------------------------------------------------- */
/* Meta tags                                                                   */
/* -------------------------------------------------------------------------- */

function fromMetaTags($, base) {
  const meta = (name) =>
    $(`meta[property="${name}"]`).attr('content') ||
    $(`meta[name="${name}"]`).attr('content') ||
    null;

  const imageUrl = absolute(
    meta('og:image:secure_url') || meta('og:image') || meta('twitter:image'),
    base,
  );
  if (!imageUrl) return null;

  // Storefronts that render the product client-side leave a site-wide og:image
  // behind — usually the logo. Cutting out a logo is worse than falling
  // through to the next strategy.
  if (NOISE.test(imageUrl)) return null;

  return {
    title: clean(meta('og:title') || $('title').first().text()),
    brand: clean(meta('product:brand') || meta('og:site_name')),
    price: formatPrice(
      meta('product:price:amount') || meta('og:price:amount'),
      meta('product:price:currency') || meta('og:price:currency'),
    ),
    imageUrl,
    source: 'og',
  };
}

/* -------------------------------------------------------------------------- */
/* Largest image                                                               */
/* -------------------------------------------------------------------------- */

/** Picks the widest candidate a srcset offers. */
function widestFromSrcset(srcset) {
  if (!srcset) return null;
  let best = null;
  let bestWidth = 0;
  for (const part of srcset.split(',')) {
    const [url, descriptor] = part.trim().split(/\s+/);
    const width = parseInt(descriptor || '0', 10) || 0;
    if (url && width >= bestWidth) {
      bestWidth = width;
      best = url;
    }
  }
  return best;
}

const NOISE = /(logo|icon|sprite|placeholder|pixel|badge|flag|payment|banner)/i;

/** Last resort: the biggest image the page declares or offers a srcset for. */
function fromLargestImage($, base) {
  let best = null;
  let bestArea = 0;

  $('img').each((_, el) => {
    const $el = $(el);
    const src =
      widestFromSrcset($el.attr('srcset') || $el.attr('data-srcset')) ||
      $el.attr('src') ||
      $el.attr('data-src') ||
      $el.attr('data-original');
    if (!src || NOISE.test(src)) return;

    const width = parseInt($el.attr('width') || '0', 10);
    const height = parseInt($el.attr('height') || '0', 10);
    const area = width * height || (/(\d{3,4})[x_/](\d{3,4})/.test(src) ? 300 * 300 : 0);
    if (area > bestArea && (width === 0 || width >= 300)) {
      bestArea = area;
      best = src;
    }
  });

  const imageUrl = absolute(best, base);
  if (!imageUrl) return null;

  return {
    title: clean($('h1').first().text() || $('title').first().text()),
    brand: null,
    price: null,
    imageUrl,
    source: 'largest-img',
  };
}

/* -------------------------------------------------------------------------- */

const STRATEGIES = [fromJsonLd, fromMicrodata, fromEmbeddedState, fromMetaTags, fromLargestImage];

/** Runs every strategy in reliability order against already-fetched HTML. */
export function parseProduct(html, base) {
  const $ = cheerio.load(html);
  const host = hostOf(base);

  for (const strategy of STRATEGIES) {
    let hit;
    try {
      hit = strategy($, base);
    } catch {
      continue; // One malformed page should not take out the whole chain.
    }
    if (!hit?.imageUrl) continue;

    return {
      ...hit,
      brand: hit.brand || siteFor(host).label || null,
      imageUrl: upgradeImage(hit.imageUrl, host),
      rawImageUrl: hit.imageUrl,
    };
  }

  return null;
}

/**
 * Pulls a product out of an arbitrary retailer page.
 *
 * Deterministic strategies run first and in order of reliability; an LLM only
 * gets involved (in index.js) when they come back thin, which keeps ingestion
 * cheap for the majority of retailers that publish structured data.
 */
export async function extractProduct(inputUrl) {
  const url = isShortener(inputUrl) ? cleanUrl(await resolveRedirect(inputUrl)) : inputUrl;

  let parsed = null;
  const page = await loadPage(url, {
    // Accept the free tier only if it actually yielded a product — a bot shell
    // returns 200 and parses to nothing, which is what the unblocker is for.
    onCandidate: ({ html, finalUrl }) => {
      parsed = parseProduct(html, finalUrl);
      return Boolean(parsed);
    },
  });

  if (!parsed) parsed = parseProduct(page.html, page.finalUrl);

  if (!parsed?.imageUrl) {
    throw Object.assign(new Error('No product image found on that page.'), { status: 422 });
  }

  return {
    ...parsed,
    pageUrl: page.finalUrl,
    fetchedVia: page.via,
    html: page.html,
  };
}
