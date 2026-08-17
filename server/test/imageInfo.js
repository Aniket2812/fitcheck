import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

import {
  inspectImage,
  validateYouCamSourceImage,
} from '../src/imageInfo.js';

const jpeg = await readFile(
  new URL('../seed/media/studio-arjun-denim-day.jpg', import.meta.url),
);
const info = validateYouCamSourceImage(jpeg);
assert.equal(info.format, 'jpeg');
assert.equal(info.width, 1122);
assert.equal(info.height, 1402);

const tinyPng = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
  'base64',
);
assert.deepEqual(inspectImage(tinyPng), {
  format: 'png',
  contentType: 'image/png',
  width: 1,
  height: 1,
});
assert.throws(
  () => validateYouCamSourceImage(tinyPng),
  /at least 512 × 384 pixels/,
);
assert.throws(
  () => validateYouCamSourceImage(Buffer.from('not an image')),
  /real JPG or PNG/,
);

console.log('image info: validates YouCam source dimensions and formats — ok');
