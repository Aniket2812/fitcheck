import { randomUUID } from 'node:crypto';

import { readMedia, saveImageBuffer } from './media.js';
import {
  configured,
  createPublishedBackground,
  publishBackgroundTemplate,
  YouCamError,
} from './providers/youcam.js';

function localMediaName(imageUrl) {
  return /^\/media\/([^/]+)$/.exec(String(imageUrl || ''))?.[1] || null;
}

/**
 * Turns a private try-on preview into a public feed image.
 *
 * Preview and draft images never pass through this function. That separation
 * is intentional: they retain the user's original room/background, while the
 * returned image uses fitcheck's one consistent neutral studio template.
 */
export async function finalizePublishedImage(
  imageUrl,
  replaceBackground = createPublishedBackground,
) {
  if (!configured) {
    throw new YouCamError(
      'YouCam background publishing is not configured on the server.',
      503,
      'youcam_not_configured',
    );
  }
  const name = localMediaName(imageUrl);
  if (!name) {
    throw new YouCamError(
      'Generate the outfit preview again before posting it.',
      422,
      'missing_local_media',
    );
  }
  const source = await readMedia(name);
  if (!source) {
    throw new YouCamError(
      'The outfit preview is no longer available. Generate it again before posting.',
      404,
      'missing_local_media',
    );
  }

  const requestId = randomUUID().slice(0, 8);
  const started = Date.now();
  console.log(`[publish-bg:${requestId}] started source=${name}`);
  try {
    const result = await replaceBackground({
      buffer: source.bytes,
      contentType: source.contentType,
    });
    const publishedUrl = await saveImageBuffer(
      result.buffer,
      result.contentType,
      'post-ready',
    );
    console.log(
      `[publish-bg:${requestId}] complete task=${result.taskId || 'local'} +${Date.now() - started}ms`,
    );
    return {
      imageUrl: publishedUrl,
      backgroundStyle: `youcam:${publishBackgroundTemplate}`,
      posePreserved: true,
      backgroundTaskId: result.taskId,
    };
  } catch (error) {
    console.error(
      `[publish-bg:${requestId}] failed +${Date.now() - started}ms: ${error.message}`,
    );
    throw error;
  }
}
