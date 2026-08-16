import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const testDir = join(tmpdir(), `compete-social-${randomUUID()}`);
process.env.DATA_FILE = join(testDir, 'social.json');
process.env.SEED_DEMO_DATA = 'false';

const store = await import('../src/store.js');

try {
  await store.loadStore();
  const user = await store.upsertGoogleUser({
    googleId: 'social-test',
    email: 'social@example.com',
    name: 'Social Test',
    picture: null,
  });
  const session = await store.createSession(user.id);
  assert.equal(store.userForToken(session.token)?.id, user.id);

  const created = await store.createPost(user.id, {
    caption: 'Weekend layers',
    imageUrl: '/media/post-test.jpg',
    garments: [
      {
        title: 'Black jacket',
        imageUrl: '/media/garment-test.webp',
        buyUrl: 'https://example.com/jacket',
        x: 0.51,
        y: 0.34,
      },
    ],
  });
  assert.equal(store.listPosts().length, 1);
  assert.equal(store.publicPost(created, user.id).garments.length, 1);

  const liked = await store.togglePostLike(created.id, user.id);
  assert.equal(liked.liked, true);
  assert.equal(store.publicPost(created, user.id).likeCount, 1);
  assert.equal(store.publicPost(created, user.id).likedByMe, true);

  await store.addPostComment(created.id, user.id, 'Clean fit.');
  assert.equal(store.publicPost(created, user.id).commentCount, 1);

  await store.deletePost(created.id, user.id);
  assert.equal(store.listPosts().length, 0);
  console.log('social store: create, feed, like, comment, delete — ok');
} finally {
  await rm(testDir, { recursive: true, force: true });
}
