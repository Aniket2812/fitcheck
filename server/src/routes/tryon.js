import { Hono } from 'hono';

import { readMedia, saveImageBuffer } from '../media.js';
import { configured, createFashionTryOn, YouCamError } from '../providers/youcam.js';
import { findModelPhoto } from '../store.js';
import { requireUser } from './auth.js';

const tryOn = new Hono();

tryOn.get('/config', (c) => c.json({ configured, provider: 'youcam-clothes-v3' }));

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
      provider: body.category === 'shoes' ? 'youcam-shoes-v2' : 'youcam-clothes-v3',
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
    return c.json({ imageUrl, taskId: result.taskId, provider: 'youcam-clothes-v3' });
  } catch (error) {
    if (error instanceof YouCamError) return c.json({ error: error.message }, error.status);
    throw error;
  }
});

export { tryOn as tryOnRoutes };
