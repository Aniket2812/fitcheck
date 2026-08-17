import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const testDir = join(tmpdir(), `compete-publish-image-${randomUUID()}`);
process.env.MEDIA_DIR = testDir;
process.env.YOUCAM_API_KEY = 'test-key';

const { readMedia, saveImageBuffer } = await import('../src/media.js');
const { finalizePublishedImage } = await import('../src/publishImage.js');

try {
  const sourceBytes = Buffer.from('private-preview-bytes');
  const sourceUrl = await saveImageBuffer(
    sourceBytes,
    'image/jpeg',
    'youcam-outfit',
  );
  let receivedSource;
  const result = await finalizePublishedImage(sourceUrl, async (source) => {
    receivedSource = source;
    return {
      buffer: Buffer.from('public-studio-bytes'),
      contentType: 'image/jpeg',
      taskId: 'background-task-test',
    };
  });

  assert.deepEqual(receivedSource.buffer, sourceBytes);
  assert.equal(receivedSource.contentType, 'image/jpeg');
  assert.notEqual(result.imageUrl, sourceUrl);
  assert.equal(result.backgroundStyle, 'youcam:neutral_linen_white');
  assert.equal(result.posePreserved, true);
  assert.equal(result.backgroundTaskId, 'background-task-test');

  const stored = await readMedia(result.imageUrl.replace('/media/', ''));
  assert.equal(stored.bytes.toString(), 'public-studio-bytes');
  await assert.rejects(
    finalizePublishedImage('https://example.com/private.jpg', async () => {}),
    (error) => error.code === 'missing_local_media',
  );
  console.log('publish image: private preview -> isolated studio post — ok');
} finally {
  await rm(testDir, { recursive: true, force: true });
}
