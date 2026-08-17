import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const baseUrl = process.env.TEST_BASE_URL || 'http://127.0.0.1:8787';
const identity = `http-photo-${Date.now()}`;

const signIn = await fetch(`${baseUrl}/api/auth/google`, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({
    idToken: `dev:${identity}:${identity}@example.com:HTTP Photo Test`,
  }),
});
assert.equal(signIn.status, 200);
const { token } = await signIn.json();
const authorization = `Bearer ${token}`;

const fullBodyPhoto = await readFile(
  new URL('../seed/media/studio-arjun-denim-day.jpg', import.meta.url),
);
const form = new FormData();
form.append(
  'image',
  new Blob([fullBodyPhoto], { type: 'image/jpeg' }),
  'full-body.jpg',
);

const upload = await fetch(`${baseUrl}/api/model-photos`, {
  method: 'POST',
  headers: { authorization },
  body: form,
});
assert.equal(upload.status, 201);
const { photo } = await upload.json();
assert.equal(photo.isPrimary, true);
assert.ok(photo.width >= 512);
assert.ok(photo.height >= 512);
assert.equal(photo.youCamReady, true);

const list = await fetch(`${baseUrl}/api/model-photos`, {
  headers: { authorization },
});
assert.equal(list.status, 200);
assert.equal((await list.json()).photos.length, 1);

const remove = await fetch(`${baseUrl}/api/model-photos/${photo.id}`, {
  method: 'DELETE',
  headers: { authorization },
});
assert.equal(remove.status, 204);

console.log('model photo HTTP API: auth, upload, list, delete — ok');
