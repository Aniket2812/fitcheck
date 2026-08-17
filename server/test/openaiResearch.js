/**
 * Live integration check for the paid OpenAI web-search fallback.
 * Kept separate from the regular parser coverage so ordinary tests stay fast.
 */
import { researchProduct } from '../src/providers/index.js';

const PRODUCT_URL =
  'https://www.myntra.com/lounge-tshirts/levis/' +
  'levis-men-soft-pure-cotton-round-neck-half-sleeve-tshirt/12027436/buy';

const started = Date.now();
const product = await researchProduct(PRODUCT_URL, { reason: 'integration-test' });

if (!/cotton|t-?shirt/i.test(product.title)) {
  throw new Error(`Unexpected product title: ${product.title}`);
}
if (!/levi/i.test(product.brand || product.title)) {
  throw new Error(`Expected Levi's product, received: ${product.brand || 'unknown brand'}`);
}
if (!product.imageUrls.length) throw new Error('No product photos were returned.');

const image = await fetch(product.imageUrls[0], {
  redirect: 'follow',
  signal: AbortSignal.timeout(30_000),
});
const contentType = image.headers.get('content-type') || '';
if (!image.ok || !contentType.startsWith('image/')) {
  throw new Error(`First product photo is not downloadable (${image.status} ${contentType}).`);
}

console.log(
  JSON.stringify(
    {
      ok: true,
      ms: Date.now() - started,
      title: product.title,
      brand: product.brand,
      price: product.price,
      images: product.imageUrls.length,
      firstImageContentType: contentType,
      fetchedVia: product.fetchedVia,
    },
    null,
    2,
  ),
);
