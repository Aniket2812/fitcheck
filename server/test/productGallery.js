import assert from 'node:assert/strict';

import { parseProduct } from '../src/extract.js';

const html = `
  <html>
    <head>
      <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Product",
          "name": "Exact white sneaker",
          "brand": { "@type": "Brand", "name": "Example" },
          "image": [
            "/shoe-front.jpg",
            "/shoe-side.jpg",
            "/shoe-back.jpg",
            "/shoe-sole.jpg",
            "/shoe-detail.jpg",
            "/shoe-sixth.jpg"
          ],
          "offers": { "price": "2999", "priceCurrency": "INR" }
        }
      </script>
    </head>
    <body><img src="/unrelated-recommendation.jpg" width="1200" height="1200"></body>
  </html>
`;

const product = parseProduct(html, 'https://shop.example.com/products/sneaker');
assert.equal(product.title, 'Exact white sneaker');
assert.equal(product.imageUrl, 'https://shop.example.com/shoe-front.jpg');
assert.deepEqual(product.imageUrls, [
  'https://shop.example.com/shoe-front.jpg',
  'https://shop.example.com/shoe-side.jpg',
  'https://shop.example.com/shoe-back.jpg',
  'https://shop.example.com/shoe-sole.jpg',
  'https://shop.example.com/shoe-detail.jpg',
]);
assert.ok(!product.imageUrls.some((url) => url.includes('recommendation')));
console.log('product gallery: exact structured images, capped to five — ok');
