import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const testDir = join(tmpdir(), `compete-saved-fits-${randomUUID()}`);
process.env.DATA_FILE = join(testDir, 'social.json');
process.env.SEED_DEMO_DATA = 'false';

const store = await import('../src/store.js');

try {
  await store.loadStore();
  const owner = await store.upsertGoogleUser({
    googleId: 'saved-fit-owner',
    email: 'drafts@example.com',
    name: 'Draft Owner',
    picture: null,
  });
  const outsider = await store.upsertGoogleUser({
    googleId: 'saved-fit-outsider',
    email: 'outsider@example.com',
    name: 'Outsider',
    picture: null,
  });

  const saved = await store.createSavedFit(owner.id, {
    caption: 'Dinner fit',
    imageUrl: '/media/youcam-fit.jpg',
    garments: [
      {
        id: 'saved-shirt',
        title: 'White shirt',
        imageUrl: '/media/white-shirt.jpg',
        productImageUrls: [
          '/media/white-shirt-front.jpg',
          '/media/white-shirt-back.jpg',
          '/media/white-shirt-side.jpg',
          '/media/white-shirt-detail.jpg',
        ],
        buyUrl: 'https://example.com/white-shirt',
        category: 'upper_body',
        x: 0.5,
        y: 0.3,
      },
      {
        id: 'saved-trousers',
        title: 'Black trousers',
        imageUrl: '/media/black-trousers.jpg',
        buyUrl: 'https://example.com/black-trousers',
        category: 'lower_body',
        x: 0.5,
        y: 0.62,
      },
    ],
  });

  assert.equal(store.listSavedFits(owner.id).length, 1);
  assert.equal(store.listSavedFits(outsider.id).length, 0);
  assert.equal(saved.garments.length, 2);
  assert.equal(saved.garments[0].productImageUrls.length, 4);
  assert.equal(saved.backgroundStyle, 'original');
  assert.equal(saved.posePreserved, true);

  await assert.rejects(
    store.publishSavedFit(outsider.id, saved.id),
    (error) => error.status === 404,
  );

  const post = await store.publishSavedFit(owner.id, saved.id, 'Ready now', {
    imageUrl: '/media/post-ready-fit.jpg',
    backgroundStyle: 'youcam:neutral_linen_white',
    posePreserved: true,
    backgroundTaskId: 'background-task-1',
  });
  assert.equal(post.caption, 'Ready now');
  assert.equal(post.imageUrl, '/media/post-ready-fit.jpg');
  assert.equal(post.backgroundStyle, 'youcam:neutral_linen_white');
  assert.equal(post.posePreserved, true);
  assert.equal(post.garments.length, 2);
  assert.equal(store.listSavedFits(owner.id).length, 0);
  assert.equal(store.listPosts().length, 1);

  const disposable = await store.createSavedFit(owner.id, {
    caption: '',
    imageUrl: '/media/another-fit.jpg',
    garments: post.garments,
  });
  await store.deleteSavedFit(owner.id, disposable.id);
  assert.equal(store.listSavedFits(owner.id).length, 0);
  console.log('saved fits: private save, list, publish, delete — ok');
} finally {
  await rm(testDir, { recursive: true, force: true });
}
