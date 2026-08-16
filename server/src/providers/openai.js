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
const CUTOUT_MODEL = process.env.OPENAI_IMAGE_MODEL || 'gpt-image-1';
const CUTOUT_QUALITY = process.env.OPENAI_IMAGE_QUALITY || 'low';
const CUTOUT_FORMAT = process.env.OPENAI_IMAGE_FORMAT || 'webp';
const CUTOUT_COMPRESSION = Number(process.env.OPENAI_IMAGE_COMPRESSION || 80);
const requestedCacheSize = Number(process.env.OPENAI_IMAGE_CACHE_SIZE || 32);
const CUTOUT_CACHE_SIZE = Number.isFinite(requestedCacheSize)
  ? Math.max(0, Math.floor(requestedCacheSize))
  : 32;
const cutoutCache = new Map();
const cutoutsInFlight = new Map();

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
