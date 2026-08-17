import { createHash } from 'node:crypto';

import OpenAI, { toFile } from 'openai';

let client;
const openai = () => {
  if (!client) {
    if (!process.env.OPENAI_API_KEY) {
      throw Object.assign(new Error('OPENAI_API_KEY is not set on the server.'), { status: 500 });
    }
    client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  }
  return client;
};

// Keep the server's longest stage bounded. The Flutter client waits longer
// than this, so it receives the real provider error instead of timing out
// first and leaving a paid image job running invisibly in the background.
const CUTOUT_TIMEOUT_MS = Number(process.env.OPENAI_CUTOUT_TIMEOUT_MS || 240_000);
const METADATA_TIMEOUT_MS = Number(process.env.OPENAI_METADATA_TIMEOUT_MS || 45_000);
const RESEARCH_TIMEOUT_MS = Number(process.env.OPENAI_RESEARCH_TIMEOUT_MS || 100_000);
const CUTOUT_MODEL = process.env.OPENAI_IMAGE_MODEL || 'gpt-image-1';
const RESEARCH_MODEL = process.env.OPENAI_RESEARCH_MODEL || 'gpt-5.6-sol';
const CUTOUT_QUALITY = process.env.OPENAI_IMAGE_QUALITY || 'low';
const CUTOUT_FORMAT = process.env.OPENAI_IMAGE_FORMAT || 'webp';
const CUTOUT_COMPRESSION = Number(process.env.OPENAI_IMAGE_COMPRESSION || 80);
const requestedCacheSize = Number(process.env.OPENAI_IMAGE_CACHE_SIZE || 32);
const CUTOUT_CACHE_SIZE = Number.isFinite(requestedCacheSize)
  ? Math.max(0, Math.floor(requestedCacheSize))
  : 32;
const cutoutCache = new Map();
const cutoutsInFlight = new Map();
const researchCache = new Map();
const researchInFlight = new Map();

const PRODUCT_RESEARCH_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['found', 'title', 'brand', 'price', 'imageUrls', 'evidenceUrls'],
  properties: {
    found: { type: 'boolean' },
    title: { type: ['string', 'null'] },
    brand: { type: ['string', 'null'] },
    price: { type: ['string', 'null'] },
    imageUrls: {
      type: 'array',
      maxItems: 8,
      items: { type: 'string' },
    },
    evidenceUrls: {
      type: 'array',
      maxItems: 5,
      items: { type: 'string' },
    },
  },
};

const httpUrls = (values) =>
  [...new Set(values || [])].filter((value) => {
    try {
      return ['http:', 'https:'].includes(new URL(value).protocol);
    } catch {
      return false;
    }
  });

const RESEARCH_IMAGE_TYPES = new Set(['image/jpeg', 'image/jpg', 'image/png', 'image/webp']);

async function reachableImageUrls(imageUrls) {
  const checks = await Promise.all(
    imageUrls.map(async (imageUrl) => {
      try {
        const response = await fetch(imageUrl, {
          headers: {
            'user-agent': 'Mozilla/5.0 AppleWebKit/537.36 Chrome/126 Safari/537.36',
            accept: 'image/avif,image/webp,image/*,*/*',
          },
          redirect: 'follow',
          signal: AbortSignal.timeout(15_000),
        });
        const contentType = String(response.headers.get('content-type') || '')
          .split(';')[0]
          .trim()
          .toLowerCase();
        await response.body?.cancel();
        return response.ok && RESEARCH_IMAGE_TYPES.has(contentType) ? imageUrl : null;
      } catch {
        return null;
      }
    }),
  );
  return checks.filter(Boolean);
}

/**
 * Finds the exact product and its original photos through OpenAI web search.
 * This is the fallback for retail pages that reject a direct server fetch.
 */
export async function researchProduct(pageUrl, { reason = 'no-product' } = {}) {
  const cached = researchCache.get(pageUrl);
  if (cached) {
    researchCache.delete(pageUrl);
    researchCache.set(pageUrl, cached);
    return cached;
  }

  const pending = researchInFlight.get(pageUrl);
  if (pending) return pending;

  const request = generateProductResearch(pageUrl, reason).then((product) => {
    researchCache.set(pageUrl, product);
    while (researchCache.size > 64) researchCache.delete(researchCache.keys().next().value);
    return product;
  });
  researchInFlight.set(pageUrl, request);

  try {
    return await request;
  } finally {
    researchInFlight.delete(pageUrl);
  }
}

async function generateProductResearch(pageUrl, reason) {
  let rejectedHosts = [];
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const researched = await requestProductResearch(pageUrl, reason, rejectedHosts);
    const imageUrls = httpUrls(researched.imageUrls).slice(0, 8);
    if (!researched.found || !researched.title || !imageUrls.length) {
      const detail = `found=${Boolean(researched.found)}, title=${Boolean(
        researched.title,
      )}, images=${imageUrls.length}`;
      throw Object.assign(
        new Error(`Could not identify that exact product through web search (${detail}).`),
        { status: 422 },
      );
    }

    const verifiedImageUrls = await reachableImageUrls(imageUrls);
    if (verifiedImageUrls.length) {
      return {
        title: researched.title.trim(),
        brand: researched.brand?.trim() || null,
        price: researched.price?.trim() || null,
        imageUrl: verifiedImageUrls[0],
        rawImageUrl: verifiedImageUrls[0],
        imageUrls: verifiedImageUrls.slice(0, 5),
        pageUrl,
        source: 'openai-web-search',
        fetchedVia: 'openai-web-search',
        evidenceUrls: httpUrls(researched.evidenceUrls).slice(0, 5),
      };
    }

    rejectedHosts = [...new Set(imageUrls.map((value) => new URL(value).hostname))];
  }

  throw Object.assign(
    new Error('OpenAI found the product, but none of its product photos were downloadable.'),
    { status: 422 },
  );
}

async function requestProductResearch(pageUrl, reason, rejectedHosts) {
  const response = await openai().responses.create(
    {
      model: RESEARCH_MODEL,
      store: false,
      reasoning: { effort: 'medium' },
      tools: [{ type: 'web_search', search_context_size: 'medium' }],
      tool_choice: 'required',
      text: {
        format: {
          type: 'json_schema',
          name: 'fashion_product_research',
          strict: true,
          schema: PRODUCT_RESEARCH_SCHEMA,
        },
      },
      input: [
        {
          role: 'system',
          content: [
            'Find the exact fashion product identified by the supplied retailer URL.',
            'Search the full URL, its product ID, and its human-readable slug.',
            'Never substitute a similar product, another colour, or another variant.',
            'Return the current product title, brand, displayed price, and up to eight',
            'directly downloadable full-size product-photo URLs. Prefer retailer or',
            'retailer-CDN images; reputable mirrors are acceptable only for the exact item.',
            'Before returning, verify each image is a public direct image URL, not a web page.',
            'Use at least two independent image hostnames whenever the sources allow it.',
            'Set found=false and use null/empty values when exact identity is uncertain.',
            'Evidence URLs must be pages that establish the exact product identity.',
          ].join(' '),
        },
        {
          role: 'user',
          content: [
            `Product URL: ${pageUrl}`,
            `Direct-fetch result: ${reason}`,
            rejectedHosts.length
              ? `Previous image hosts were not downloadable: ${rejectedHosts.join(', ')}. Find alternatives.`
              : '',
          ]
            .filter(Boolean)
            .join('\n'),
        },
      ],
    },
    { timeout: RESEARCH_TIMEOUT_MS, maxRetries: 0 },
  );

  try {
    return JSON.parse(response.output_text);
  } catch {
    throw Object.assign(new Error('OpenAI product research returned invalid data.'), {
      status: 502,
    });
  }
}

/**
 * Deliberately says nothing about an outline.
 *
 * Asking the model for one produced a different result every time — a yellow
 * glow on one garment, a thick white rim on the next — and baked it into the
 * pixels permanently. The outline is drawn in the app instead
 * (components/CutoutImage), where it is one consistent grey and can be changed
 * without re-ingesting anything.
 */
const CUTOUT_PROMPT = [
  'Isolate only the single clothing item worn or shown as the main subject.',
  'Remove the background, any model, mannequin, hanger, props and shadows completely.',
  'Output the garment on a fully transparent background, cropped to the garment.',
  'Keep the original colour, print, fabric texture and proportions exactly as they are.',
  'Do not stylise, redraw or smooth the pattern. Do not add an outline, glow, shadow,',
  'text, watermark or any new element.',
].join(' ');

/**
 * Cuts the garment out of a product photo.
 * Returns a transparent image as a data URL. Successful results are cached by
 * source pixels, and simultaneous requests for the same image share one paid
 * provider call.
 */
export async function cutout(imageBuffer) {
  const cacheKey = createHash('sha256').update(imageBuffer).digest('hex');
  const cached = cutoutCache.get(cacheKey);
  if (cached) {
    // Refresh insertion order so the bounded map behaves like an LRU cache.
    cutoutCache.delete(cacheKey);
    cutoutCache.set(cacheKey, cached);
    return cached;
  }

  const pending = cutoutsInFlight.get(cacheKey);
  if (pending) return pending;

  const request = generateCutout(imageBuffer).then((image) => {
    cutoutCache.set(cacheKey, image);
    while (cutoutCache.size > CUTOUT_CACHE_SIZE) {
      cutoutCache.delete(cutoutCache.keys().next().value);
    }
    return image;
  });
  cutoutsInFlight.set(cacheKey, request);

  try {
    return await request;
  } finally {
    cutoutsInFlight.delete(cacheKey);
  }
}

async function generateCutout(imageBuffer) {
  const file = await toFile(imageBuffer, 'product.png', { type: 'image/png' });

  const result = await openai().images.edit(
    {
      model: CUTOUT_MODEL,
      image: file,
      prompt: CUTOUT_PROMPT,
      size: '1024x1024',
      quality: CUTOUT_QUALITY,
      background: 'transparent',
      output_format: CUTOUT_FORMAT,
      ...(CUTOUT_FORMAT === 'webp' || CUTOUT_FORMAT === 'jpeg'
        ? { output_compression: CUTOUT_COMPRESSION }
        : {}),
    },
    {
      timeout: CUTOUT_TIMEOUT_MS,
      // A retry can double the wall-clock time and charge for a second image
      // after the phone has already given up. Let the user retry explicitly.
      maxRetries: 0,
    },
  );

  const b64 = result.data?.[0]?.b64_json;
  if (!b64) {
    throw Object.assign(new Error('The cutout step returned no image.'), { status: 502 });
  }
  return `data:image/${CUTOUT_FORMAT};base64,${b64}`;
}

/**
 * Fallback metadata reader for pages with no structured data. Only called when
 * the deterministic extractors come back empty.
 */
export async function describeProduct({ title, pageUrl }) {
  const response = await openai().chat.completions.create(
    {
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content:
            'You label fashion products. Reply with compact JSON only: ' +
            '{"title":string,"brand":string|null,"category":string}. ' +
            'category is one of: top, bottom, dress, outerwear, shoes, accessory.',
        },
        { role: 'user', content: `Page title: ${title || 'unknown'}\nURL: ${pageUrl}` },
      ],
      response_format: { type: 'json_object' },
    },
    { timeout: METADATA_TIMEOUT_MS, maxRetries: 0 },
  );

  try {
    return JSON.parse(response.choices[0].message.content);
  } catch {
    return { title: title || 'Saved piece', brand: null, category: 'top' };
  }
}

export const name = 'openai';
export const researchConfigured = Boolean(process.env.OPENAI_API_KEY);
