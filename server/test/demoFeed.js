import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const testDir = join(tmpdir(), `compete-demo-feed-${randomUUID()}`);
process.env.DATA_FILE = join(testDir, 'social.json');
process.env.SEED_DEMO_DATA = 'true';

const store = await import('../src/store.js');
const { readMedia } = await import('../src/media.js');
const { seedDemoFeed } = await import('../src/demoFeed.js');
const visualMatches = JSON.parse(
  await readFile(new URL('../seed/visual-matches.json', import.meta.url), 'utf8'),
);

try {
  await store.loadStore();
  const posts = store.listPosts();
  assert.equal(posts.length, 24);
  assert.equal(
    posts.reduce((total, post) => total + post.garments.length, 0),
    88,
  );

  assert.equal(visualMatches.matches.length, 88);
  const matchesByGarment = new Map(
    visualMatches.matches.map((match) => [match.garmentId, match]),
  );

  const retailerHosts = new Set([
    'www2.hm.com',
    'in.puma.com',
    'www.uniqlo.com',
    'levi.in',
    'www.charleskeith.in',
    'shop.mango.com',
    'www.adidas.co.in',
    'www.amazon.in',
    'www.myntra.com',
    'www.ajio.com',
    'www.flipkart.com',
  ]);
  const retailerCounts = new Map();
  const productsByCatalogKey = new Map();
  const catalogKeysByBuyUrl = new Map();
  assert.equal(new Set(posts.map((post) => post.imageUrl)).size, posts.length);
  for (const post of posts) {
    assert.match(post.imageUrl, /^\/media\/[a-z0-9-]+\.jpg$/);
    const postImage = await readMedia(post.imageUrl.replace('/media/', ''));
    assert.equal(postImage.contentType, 'image/jpeg');
    assert.ok(postImage.bytes.length > 20_000);

    for (const garment of post.garments) {
      const visualMatch = matchesByGarment.get(garment.id);
      assert.ok(visualMatch, `Missing visual audit for ${garment.id}`);
      assert.equal(visualMatch.postId, post.id);
      assert.equal(visualMatch.postImage, post.imageUrl);
      assert.equal(visualMatch.productImage, garment.imageUrl);
      assert.equal(visualMatch.catalogKey, garment.catalogKey);
      assert.equal(visualMatch.retailerSku, garment.retailerSku);
      assert.equal(visualMatch.buyUrl, garment.buyUrl);
      assert.ok(visualMatch.colour);
      assert.ok(visualMatch.product);
      assert.ok(garment.catalogKey);
      assert.ok(garment.retailerSku);
      assert.ok(Array.isArray(garment.productImageUrls));
      assert.deepEqual(
        garment.productImageUrls,
        [garment.imageUrl],
        `Mock gallery for ${garment.id} must contain one honest product frame`,
      );

      assert.match(garment.imageUrl, /^\/media\/[a-z0-9-]+\.jpg$/);
      const productImage = await readMedia(
        garment.imageUrl.replace('/media/', ''),
      );
      assert.equal(productImage.contentType, 'image/jpeg');
      assert.ok(productImage.bytes.length > 20_000);

      const productUrl = new URL(garment.buyUrl);
      assert.equal(productUrl.protocol, 'https:');
      assert.ok(retailerHosts.has(productUrl.host));
      retailerCounts.set(
        productUrl.host,
        (retailerCounts.get(productUrl.host) || 0) + 1,
      );

      const identity = JSON.stringify({
        title: garment.title,
        brand: garment.brand,
        price: garment.price,
        imageUrl: garment.imageUrl,
        productImageUrls: garment.productImageUrls,
        buyUrl: garment.buyUrl,
        retailerSku: garment.retailerSku,
        category: garment.category,
      });
      const existingIdentity = productsByCatalogKey.get(garment.catalogKey);
      if (existingIdentity) {
        assert.equal(
          identity,
          existingIdentity,
          `${garment.catalogKey} must always open the same retailer SKU`,
        );
      } else {
        productsByCatalogKey.set(garment.catalogKey, identity);
      }
      const existingKey = catalogKeysByBuyUrl.get(garment.buyUrl);
      if (existingKey) {
        assert.equal(
          garment.catalogKey,
          existingKey,
          `${garment.buyUrl} cannot represent two mock products`,
        );
      } else {
        catalogKeysByBuyUrl.set(garment.buyUrl, garment.catalogKey);
      }

      assert.equal(productUrl.pathname.includes('/search'), false);
      assert.equal(productUrl.pathname.includes('/search-results'), false);

      if (productUrl.host === 'www.amazon.in') {
        assert.match(productUrl.pathname, /\/dp\/[A-Z0-9]{10}$/);
      }
      if (productUrl.host === 'www.ajio.com') {
        assert.match(productUrl.pathname, /\/p\/[a-z0-9_]+$/i);
      }
      if (productUrl.host === 'www.myntra.com') {
        assert.match(productUrl.pathname, /\/\d+\/buy$/);
      }
      if (productUrl.host === 'www2.hm.com') {
        assert.match(productUrl.pathname, /\/productpage\.\d+\.html$/);
      }
      if (productUrl.host === 'in.puma.com') {
        assert.match(productUrl.pathname, /\/pd\/.+\/\d+$/);
      }
      if (productUrl.host === 'www.uniqlo.com') {
        assert.match(productUrl.pathname, /\/products\/E\d+-\d+\/\d+$/);
      }
      if (productUrl.host === 'levi.in') {
        assert.match(productUrl.pathname, /\/products\/[a-z0-9-]+$/);
      }
      if (productUrl.host === 'www.charleskeith.in') {
        assert.match(productUrl.pathname, /\/CK.+\.html$/);
      }
      if (productUrl.host === 'shop.mango.com') {
        assert.match(productUrl.pathname, /(?:_|\/)\d{8}(?:\/|$)/);
      }
      if (productUrl.host === 'www.adidas.co.in') {
        assert.match(productUrl.pathname, /\/[A-Z0-9]+\.html$/i);
      }
      if (
        ['www.amazon.in', 'www.ajio.com', 'www.myntra.com'].includes(
          productUrl.host,
        )
      ) {
        assert.equal(productUrl.pathname.startsWith('/search'), false);
        assert.equal(productUrl.searchParams.has('k'), false);
        assert.equal(productUrl.searchParams.has('text'), false);
      }
    }
  }
  assert.equal(matchesByGarment.size, 88);
  assert.equal(productsByCatalogKey.size, 52);
  assert.equal(catalogKeysByBuyUrl.size, 52);
  assert.ok(retailerCounts.get('www.amazon.in') >= 1);
  assert.ok(retailerCounts.get('www.ajio.com') >= 8);
  assert.ok(retailerCounts.get('www.myntra.com') >= 10);

  const accessoryCounts = posts.map(
    (post) =>
      post.garments.filter((garment) => garment.category === 'accessory')
        .length,
  );
  assert.ok(accessoryCounts.some((count) => count === 0));
  assert.ok(accessoryCounts.some((count) => count > 0));
  assert.ok(posts.every((post) => post.garments.length >= 2));
  assert.ok(
    posts.every(
      (post) =>
        new Set(post.garments.map((garment) => garment.buyUrl)).size ===
        post.garments.length,
    ),
    'Every mock post should link each piece to a different product',
  );

  const remixPosts = posts.filter((post) => post.id.endsWith('-remix'));
  assert.equal(remixPosts.length, 10);
  assert.equal(
    new Set(remixPosts.map((post) => post.imageUrl)).size,
    remixPosts.length,
  );
  assert.ok(
    remixPosts.some(
      (post) =>
        !post.garments.some((garment) => garment.category === 'accessory'),
    ),
  );
  assert.ok(
    remixPosts.some((post) =>
      post.garments.some((garment) => garment.category === 'accessory'),
    ),
  );

  const cityLayers = posts.find((post) => post.id === 'demo-post-city-layers');
  assert.ok(cityLayers);
  const projected = store.publicPost(cityLayers);
  assert.equal(projected.author.handle, 'mayamixes');
  assert.equal(projected.likeCount, 3);
  assert.equal(projected.commentCount, 2);
  assert.equal(projected.garments.length, 4);
  assert.equal(projected.imageUrl, '/media/studio-maya-city-layers.jpg');
  assert.equal(projected.garments[0].imageUrl, '/media/maya-black-blazer.jpg');
  assert.match(projected.garments[0].buyUrl, /^https:\/\/www2\.hm\.com\/en_in\/productpage\./);

  const seededImage = await readMedia('studio-maya-city-layers.jpg');
  assert.equal(seededImage.contentType, 'image/jpeg');
  assert.ok(seededImage.bytes.length > 100_000);

  const persisted = JSON.parse(await readFile(process.env.DATA_FILE, 'utf8'));
  assert.equal(persisted.demoFeedVersion, 10);
  assert.equal(persisted.posts.length, 24);

  await store.loadStore();
  assert.equal(store.listPosts().length, 24);

  const preservedCreatedAt = '2026-01-01T00:00:00.000Z';
  const migrationDb = {
    users: new Map(),
    posts: new Map([
      [
        'demo-post-city-layers',
        {
          id: 'demo-post-city-layers',
          demo: true,
          likeUserIds: ['existing-viewer'],
          comments: [
            {
              id: 'existing-comment',
              userId: 'existing-viewer',
              text: 'Keep me',
              createdAt: preservedCreatedAt,
            },
          ],
          createdAt: preservedCreatedAt,
        },
      ],
    ]),
  };
  const migration = await seedDemoFeed(
    migrationDb,
    2,
    Date.parse('2026-08-17T00:00:00.000Z'),
  );
  assert.equal(migration.version, 10);
  assert.equal(migrationDb.posts.size, 24);
  const migratedPost = migrationDb.posts.get('demo-post-city-layers');
  assert.deepEqual(migratedPost.likeUserIds, ['existing-viewer']);
  assert.equal(migratedPost.comments[0].text, 'Keep me');
  assert.equal(migratedPost.createdAt, preservedCreatedAt);
  assert.equal(migratedPost.imageUrl, '/media/studio-maya-city-layers.jpg');
  console.log('demo feed: seeded, projected, persisted, idempotent — ok');
} finally {
  await rm(testDir, { recursive: true, force: true });
}
