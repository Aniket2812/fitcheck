import { randomUUID } from 'node:crypto';

import { serve } from '@hono/node-server';
import { Hono } from 'hono';
import { cors } from 'hono/cors';

import { extractProduct } from './extract.js';
import { BROWSER_HEADERS, unblockerReady } from './fetchPage.js';
import { googleConfigured } from './google.js';
import { normalizeInput } from './links.js';
import { readMedia, saveImageBuffer } from './media.js';
import { supportedSites } from './sites.js';
import { cutoutProvider, describeProduct } from './providers/index.js';
import { configured as youcamConfigured } from './providers/youcam.js';
import { authRoutes, meRoutes, userRoutes } from './routes/auth.js';
import { collectionRoutes } from './routes/collections.js';
import { modelPhotoRoutes } from './routes/modelPhotos.js';
import { postRoutes } from './routes/posts.js';
import { savedFitRoutes } from './routes/savedFits.js';
import { tryOnRoutes } from './routes/tryon.js';
import { loadStore } from './store.js';

const app = new Hono();
const IMAGE_DOWNLOAD_TIMEOUT_MS = Number(process.env.IMAGE_DOWNLOAD_TIMEOUT_MS || 30_000);

// The app runs on a device/emulator on the LAN, so it is never same-origin.
app.use('/*', cors());

app.get('/health', (c) =>
  c.json({
    ok: true,
    provider: cutoutProvider.name,
    hasKey: Boolean(process.env.OPENAI_API_KEY),
    youcam: youcamConfigured ? 'configured' : 'missing-key',
    googleAuth: googleConfigured ? 'configured' : 'dev',
    unblocker: unblockerReady() ? 'brightdata' : 'none',
    sites: supportedSites().length,
  }),
);

app.route('/api/auth', authRoutes);
app.route('/api/me', meRoutes);
app.route('/api/users', userRoutes);
app.route('/api/collections', collectionRoutes);
app.route('/api/model-photos', modelPhotoRoutes);
app.route('/api/posts', postRoutes);
app.route('/api/saved-fits', savedFitRoutes);
app.route('/api/try-on', tryOnRoutes);

app.get('/media/:name', async (c) => {
  const media = await readMedia(c.req.param('name'));
  if (!media) return c.json({ error: 'Image not found.' }, 404);
  c.header('content-type', media.contentType);
  c.header('cache-control', 'public, max-age=31536000, immutable');
  return c.body(media.bytes);
});

/** Lets the client show "works with…" without hardcoding the list twice. */
app.get('/api/sites', (c) => c.json({ sites: supportedSites() }));

/**
 * Product image CDNs reject hotlinks with no referer far more often than they
 * reject an odd user-agent, so mirror the page we found the image on.
 */
async function downloadImage(imageUrl, pageUrl) {
  return fetch(imageUrl, {
    headers: { ...BROWSER_HEADERS, accept: 'image/avif,image/webp,image/*,*/*', referer: pageUrl },
    redirect: 'follow',
    signal: AbortSignal.timeout(IMAGE_DOWNLOAD_TIMEOUT_MS),
  });
}

const galleryContentType = (response) =>
  String(response.headers.get('content-type') || '')
    .split(';')[0]
    .trim()
    .toLowerCase();

async function persistProductImage(response) {
  if (!response.ok) return null;
  const contentType = galleryContentType(response);
  if (!['image/jpeg', 'image/jpg', 'image/png', 'image/webp'].includes(contentType)) {
    return null;
  }
  return saveImageBuffer(Buffer.from(await response.arrayBuffer()), contentType, 'product');
}

async function cacheProductGallery(product, primaryImage, primaryBuffer) {
  const stored = [];
  try {
    const primaryType = galleryContentType(primaryImage);
    if (primaryType) {
      stored.push(await saveImageBuffer(primaryBuffer, primaryType, 'product'));
    }
  } catch {
    // The remote original remains a valid gallery fallback below.
  }

  const candidates = [...new Set(product.imageUrls || [])]
    .filter((imageUrl) => imageUrl && imageUrl !== product.imageUrl)
    .slice(0, 4);
  const extras = await Promise.all(
    candidates.map(async (imageUrl) => {
      try {
        return await persistProductImage(await downloadImage(imageUrl, product.pageUrl));
      } catch {
        return null;
      }
    }),
  );
  stored.push(...extras.filter(Boolean));

  const gallery = [...new Set(stored.length ? stored : [product.imageUrl])].slice(0, 5);
  while (gallery.length < 4) gallery.push(gallery.at(-1));
  return gallery;
}

function inferFashionCategory(...values) {
  const text = values.filter(Boolean).join(' ').toLowerCase();
  if (/\b(shoe|shoes|sneaker|sneakers|loafer|loafers|boot|boots|sandal|slipper|heels?)\b/.test(text)) {
    return 'shoes';
  }
  if (/\b(ring|earring|bracelet|necklace|watch|bag|handbag|belt|sunglasses|accessor)/.test(text)) {
    return 'accessory';
  }
  if (/\b(dress|gown|jumpsuit|romper|saree|sari)\b/.test(text)) return 'full_body';
  if (/\b(jeans|trouser|pants|shorts|skirt|jogger|leggings|bottom)\b/.test(text)) {
    return 'lower_body';
  }
  return 'upper_body';
}

/**
 * POST /api/ingest  { url }
 *
 * Share text -> product image + metadata -> transparent cutout.
 * Returns everything the client needs to render a closet item.
 */
app.post('/api/ingest', async (c) => {
  const requestId = randomUUID().slice(0, 8);
  const started = Date.now();
  let stage = 'request';
  const mark = (next, detail = '') => {
    stage = next;
    console.log(
      `[ingest:${requestId}] ${next} +${Date.now() - started}ms${detail ? ` ${detail}` : ''}`,
    );
  };

  mark('started');
  let body;
  try {
    body = await c.req.json();
  } catch {
    console.warn(`[ingest:${requestId}] invalid-json +${Date.now() - started}ms`);
    return c.json({ error: 'Send a JSON body with a url.' }, 400);
  }

  try {
    // Accepts a raw paste: share text, a shortener, or an app deep link.
    stage = 'normalise';
    const url = normalizeInput(body?.url ?? body?.text);
    mark('normalised', new URL(url).hostname);

    stage = 'extract-product';
    const product = await extractProduct(url);
    mark('product-extracted', `${product.fetchedVia}/${product.source}`);

    // Only pay for an LLM call when the page gave us nothing useful.
    let { title, brand } = product;
    let category = null;
    if (!title) {
      stage = 'describe-product';
      const described = await describeProduct(product);
      title = described.title;
      brand = brand || described.brand;
      category = described.category;
      mark('product-described');
    }
    category = category || inferFashionCategory(title, product.pageUrl);

    // The upgraded (full-size) URL is a rewrite, so fall back to the original
    // if the CDN does not recognise it.
    stage = 'download-image';
    let imageResponse = await downloadImage(product.imageUrl, product.pageUrl);
    let sourceImage = product.imageUrl;
    if (!imageResponse.ok && product.rawImageUrl && product.rawImageUrl !== product.imageUrl) {
      imageResponse = await downloadImage(product.rawImageUrl, product.pageUrl);
      sourceImage = product.rawImageUrl;
    }
    if (!imageResponse.ok) {
      throw Object.assign(new Error('Could not download the product image.'), { status: 422 });
    }

    const buffer = Buffer.from(await imageResponse.arrayBuffer());
    mark('image-downloaded', `${Math.round(buffer.length / 1024)}KB`);

    stage = 'cache-gallery';
    const productImageUrls = await cacheProductGallery(product, imageResponse, buffer);
    mark('gallery-cached', `${new Set(productImageUrls).size}/${productImageUrls.length}-images`);

    stage = 'cutout';
    const image = await cutoutProvider.cutout(buffer);
    mark('cutout-complete');

    const result = {
      id: `item-${Date.now()}`,
      title: title || 'Saved piece',
      brand: brand || null,
      price: product.price || null,
      category,
      image,
      originalImage: sourceImage,
      productImageUrls,
      pageUrl: product.pageUrl,
      extractedVia: product.source,
      fetchedVia: product.fetchedVia,
    };
    mark('complete', `${Math.round(image.length / 1024)}KB-data-url`);
    return c.json(result);
  } catch (error) {
    const status = error.status || 500;
    console.error(
      `[ingest:${requestId}] failed stage=${stage} status=${status} ` +
        `+${Date.now() - started}ms: ${error.message || error}`,
    );
    return c.json({ error: error.message || 'Ingestion failed.' }, status);
  }
});

const port = Number(process.env.PORT || 8787);

// Accounts are read from disk before the first request, so a restart never
// serves an empty user table and signs everyone out.
await loadStore();

serve({ fetch: app.fetch, port, hostname: '0.0.0.0' }, () => {
  console.log(`fitterest server on http://0.0.0.0:${port} (provider: ${cutoutProvider.name})`);
  if (!googleConfigured) {
    console.warn('[auth] no GOOGLE_CLIENT_ID — accepting dev sign-ins only');
  }
});
