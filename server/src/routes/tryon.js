import { Hono } from 'hono';

import { saveImageBuffer } from '../media.js';
import { configured, createTryOn, YouCamError } from '../providers/youcam.js';
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
    const result = await createTryOn({
      personBuffer: Buffer.from(await photo.arrayBuffer()),
      personContentType: photo.type,
      garmentUrl: String(form.get('garmentUrl') || ''),
      category: String(form.get('category') || 'upper_body'),
    });
    const imageUrl = await saveImageBuffer(result.buffer, result.contentType, 'youcam');
    return c.json({ imageUrl, taskId: result.taskId, provider: 'youcam-clothes-v3' });
  } catch (error) {
    if (error instanceof YouCamError) return c.json({ error: error.message }, error.status);
    throw error;
  }
});

export { tryOn as tryOnRoutes };
