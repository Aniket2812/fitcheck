import { randomUUID } from 'node:crypto';

import { Hono } from 'hono';

import { readMedia, saveImageBuffer } from '../media.js';
import {
  configured,
  createCompleteLookTryOn,
  createFashionTryOn,
  createOutfitTryOn,
  YouCamError,
} from '../providers/youcam.js';
import { findModelPhoto, findPostById } from '../store.js';
import { requireUser } from './auth.js';

const tryOn = new Hono();

tryOn.get('/config', (c) => c.json({ configured, provider: 'youcam-clothes-v3' }));

function localMediaName(imageUrl) {
  return /^\/media\/([^/]+)$/.exec(String(imageUrl || ''))?.[1] || null;
}

async function localMedia(imageUrl, missingMessage) {
  const name = localMediaName(imageUrl);
  if (!name) throw new YouCamError(missingMessage, 422, 'missing_local_media');
  const media = await readMedia(name);
  if (!media) throw new YouCamError(missingMessage, 404, 'missing_local_media');
  return media;
}

tryOn.post('/post', requireUser, async (c) => {
  if (!configured) {
    return c.json({ error: 'YouCam is not configured on the server.' }, 503);
  }
  const requestId = randomUUID().slice(0, 8);
  const started = Date.now();
  try {
    const body = await c.req.json();
    const photo = findModelPhoto(
      c.get('user').id,
      String(body?.modelPhotoId || ''),
    );
    if (!photo) {
      return c.json({ error: 'Choose one of your saved full-body photos.' }, 404);
    }
    const post = findPostById(String(body?.postId || ''));
    if (!post) return c.json({ error: 'This outfit post no longer exists.' }, 404);
    if (!post.garments?.length) {
      return c.json({ error: 'This post has no outfit pieces to transfer.' }, 422);
    }

    console.log(
      `[try-on:${requestId}] full-look-start post=${post.id} pieces=${post.garments.length}`,
    );
    const [person, reference] = await Promise.all([
      localMedia(
        photo.imageUrl,
        'Re-upload the selected full-body photo before trying this look.',
      ),
      localMedia(
        post.imageUrl,
        'This post does not have a reusable outfit image.',
      ),
    ]);
    const result = await createCompleteLookTryOn({
      personBuffer: person.bytes,
      personContentType: person.contentType,
      referenceBuffer: reference.bytes,
      referenceContentType: reference.contentType,
    });
    const imageUrl = await saveImageBuffer(
      result.buffer,
      result.contentType,
      'youcam-complete-look',
    );
    console.log(
      `[try-on:${requestId}] full-look-complete task=${result.taskId} +${Date.now() - started}ms`,
    );
    return c.json({
      imageUrl,
      taskId: result.taskId,
      appliedCount: post.garments.length,
      provider: 'youcam-clothes-v3-full-look',
      preservesSourceComposition: true,
    });
  } catch (error) {
    if (error instanceof YouCamError) {
      console.error(
        `[try-on:${requestId}] full-look-failed code=${error.code} +${Date.now() - started}ms: ${error.message}`,
      );
      return c.json(
        { error: error.message, code: error.code, retryable: error.retryable },
        error.status,
      );
    }
    throw error;
  }
});

tryOn.post('/', requireUser, async (c) => {
  if (!configured) return c.json({ error: 'YouCam is not configured on the server.' }, 503);
  try {
    const form = await c.req.formData();
    const photo = form.get('photo');
    if (!photo || typeof photo.arrayBuffer !== 'function') {
      return c.json({ error: 'Choose a photo for virtual try-on.' }, 400);
    }
    if (photo.size > 10 * 1024 * 1024) {
      return c.json({ error: 'The YouCam source photo must be under 10 MB.' }, 413);
    }
    const result = await createFashionTryOn({
      personBuffer: Buffer.from(await photo.arrayBuffer()),
      personContentType: photo.type,
      garmentUrl: String(form.get('garmentUrl') || ''),
      category: String(form.get('category') || 'upper_body'),
    });
    const imageUrl = await saveImageBuffer(result.buffer, result.contentType, 'youcam');
    return c.json({
      imageUrl,
      taskId: result.taskId,
      provider:
        String(form.get('category') || '') === 'shoes'
          ? 'youcam-shoes-v2'
          : 'youcam-clothes-v3',
    });
  } catch (error) {
    if (error instanceof YouCamError) return c.json({ error: error.message }, error.status);
    throw error;
  }
});

tryOn.post('/model', requireUser, async (c) => {
  if (!configured) return c.json({ error: 'YouCam is not configured on the server.' }, 503);
  try {
    const body = await c.req.json();
    const photo = findModelPhoto(c.get('user').id, String(body?.modelPhotoId || ''));
    if (!photo) return c.json({ error: 'Choose one of your saved full-body photos.' }, 404);
    const match = /^\/media\/([^/]+)$/.exec(photo.imageUrl);
    if (!match) {
      return c.json({ error: 'Re-upload this photo before using it for try-on.' }, 422);
    }
    const media = await readMedia(match[1]);
    if (!media) return c.json({ error: 'The selected full-body photo is missing.' }, 404);
    const result = await createFashionTryOn({
      personBuffer: media.bytes,
      personContentType: media.contentType,
      garmentUrl: String(body?.garmentUrl || ''),
      category: String(body?.category || 'upper_body'),
    });
    const imageUrl = await saveImageBuffer(result.buffer, result.contentType, 'youcam');
    return c.json({
      imageUrl,
      taskId: result.taskId,
      provider: body.category === 'shoes' ? 'youcam-shoes-v2' : 'youcam-clothes-v3',
    });
  } catch (error) {
    if (error instanceof YouCamError) return c.json({ error: error.message }, error.status);
    throw error;
  }
});

tryOn.post('/outfit', requireUser, async (c) => {
  if (!configured) return c.json({ error: 'YouCam is not configured on the server.' }, 503);
  try {
    const body = await c.req.json();
    const photo = findModelPhoto(c.get('user').id, String(body?.modelPhotoId || ''));
    if (!photo) return c.json({ error: 'Choose one of your saved full-body photos.' }, 404);
    const match = /^\/media\/([^/]+)$/.exec(photo.imageUrl);
    if (!match) return c.json({ error: 'Re-upload this photo before using it for try-on.' }, 422);
    const media = await readMedia(match[1]);
    if (!media) return c.json({ error: 'The selected full-body photo is missing.' }, 404);
    const garments = Array.isArray(body?.garments)
      ? body.garments.map((garment) => ({
          garmentUrl: String(garment?.garmentUrl || ''),
          category: String(garment?.category || 'upper_body'),
        }))
      : [];
    const result = await createOutfitTryOn({
      personBuffer: media.bytes,
      personContentType: media.contentType,
      garments,
    });
    const imageUrl = await saveImageBuffer(result.buffer, result.contentType, 'youcam-outfit');
    return c.json({
      imageUrl,
      taskIds: result.taskIds,
      appliedCount: result.appliedCount,
      skippedCategories: result.skippedCategories,
      provider: 'youcam-outfit-pipeline',
    });
  } catch (error) {
    if (error instanceof YouCamError) return c.json({ error: error.message }, error.status);
    throw error;
  }
});

export { tryOn as tryOnRoutes };
