import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const testDir = join(tmpdir(), `compete-model-photos-${randomUUID()}`);
process.env.DATA_FILE = join(testDir, 'model-photos.json');

const store = await import('../src/store.js');

try {
  await store.loadStore();
  const user = await store.upsertGoogleUser({
    googleId: 'model-photo-test',
    email: 'photos@example.com',
    name: 'Photo Test',
    picture: null,
  });

  const first = await store.addModelPhoto(user.id, '/media/model-one.jpg', 'Front');
  const second = await store.addModelPhoto(user.id, '/media/model-two.jpg', 'Street');
  assert.equal(first.isPrimary, true);
  assert.equal(second.isPrimary, false);
  assert.equal(store.listModelPhotos(user.id).length, 2);

  await store.setPrimaryModelPhoto(user.id, second.id);
  assert.equal(store.findModelPhoto(user.id, second.id).isPrimary, true);

  await store.deleteModelPhoto(user.id, second.id);
  const remaining = store.listModelPhotos(user.id);
  assert.equal(remaining.length, 1);
  assert.equal(remaining[0].isPrimary, true);
  console.log('model photos: add, select primary, list, delete — ok');
} finally {
  await rm(testDir, { recursive: true, force: true });
}
