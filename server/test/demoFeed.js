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
  assert.equal(posts.length, 14);
  assert.equal(
    posts.reduce((total, post) => total + post.garments.length, 0),
    18,
  );

  assert.equal(visualMatches.matches.length, 18);
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
  ]);
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
      assert.ok(visualMatch.colour);
      assert.ok(visualMatch.product);

      assert.match(garment.imageUrl, /^\/media\/[a-z0-9-]+\.jpg$/);
      const productImage = await readMedia(
        garment.imageUrl.replace('/media/', ''),
      );
      assert.equal(productImage.contentType, 'image/jpeg');
      assert.ok(productImage.bytes.length > 20_000);

      const productUrl = new URL(garment.buyUrl);
      assert.equal(productUrl.protocol, 'https:');
      assert.ok(retailerHosts.has(productUrl.host));
    }
  }
  assert.equal(matchesByGarment.size, 18);

  const cityLayers = posts.find((post) => post.id === 'demo-post-city-layers');
  assert.ok(cityLayers);
  const projected = store.publicPost(cityLayers);
  assert.equal(projected.author.handle, 'mayamixes');
  assert.equal(projected.likeCount, 3);
  assert.equal(projected.commentCount, 2);
  assert.equal(projected.garments.length, 2);
  assert.equal(projected.imageUrl, '/media/studio-maya-city-layers.jpg');
  assert.equal(projected.garments[0].imageUrl, '/media/maya-black-blazer.jpg');
  assert.match(projected.garments[0].buyUrl, /^https:\/\/www2\.hm\.com\/en_in\/productpage\./);

  const seededImage = await readMedia('studio-maya-city-layers.jpg');
  assert.equal(seededImage.contentType, 'image/jpeg');
  assert.ok(seededImage.bytes.length > 100_000);

  const persisted = JSON.parse(await readFile(process.env.DATA_FILE, 'utf8'));
  assert.equal(persisted.demoFeedVersion, 4);
  assert.equal(persisted.posts.length, 14);

  await store.loadStore();
  assert.equal(store.listPosts().length, 14);

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
  assert.equal(migration.version, 4);
  assert.equal(migrationDb.posts.size, 14);
  const migratedPost = migrationDb.posts.get('demo-post-city-layers');
  assert.deepEqual(migratedPost.likeUserIds, ['existing-viewer']);
  assert.equal(migratedPost.comments[0].text, 'Keep me');
  assert.equal(migratedPost.createdAt, preservedCreatedAt);
  assert.equal(migratedPost.imageUrl, '/media/studio-maya-city-layers.jpg');
  console.log('demo feed: seeded, projected, persisted, idempotent — ok');
} finally {
  await rm(testDir, { recursive: true, force: true });
}
