import { Hono } from 'hono';

import {
  createSavedFit,
  deleteSavedFit,
  getSavedFit,
  listSavedFits,
  PostError,
  publicPost,
  publishSavedFit,
  SavedFitError,
} from '../store.js';
import { finalizePublishedImage } from '../publishImage.js';
import { YouCamError } from '../providers/youcam.js';
import { requireUser } from './auth.js';

const savedFits = new Hono();
savedFits.use('/*', requireUser);

function fail(c, error) {
  if (
    error instanceof SavedFitError ||
    error instanceof PostError ||
    error instanceof YouCamError
  ) {
    return c.json({ error: error.message }, error.status);
  }
  throw error;
}

savedFits.get('/', (c) => {
  try {
    return c.json({ savedFits: listSavedFits(c.get('user').id) });
  } catch (error) {
    return fail(c, error);
  }
});

savedFits.post('/', async (c) => {
  try {
    const body = await c.req.json();
    const savedFit = await createSavedFit(c.get('user').id, body);
    return c.json({ savedFit }, 201);
  } catch (error) {
    return fail(c, error);
  }
});

savedFits.post('/:id/publish', async (c) => {
  try {
    const body = await c.req.json().catch(() => ({}));
    const userId = c.get('user').id;
    const fitId = c.req.param('id');
    const fit = getSavedFit(userId, fitId);
    const publishedImage = await finalizePublishedImage(fit.imageUrl);
    const post = await publishSavedFit(
      userId,
      fitId,
      body?.caption,
      publishedImage,
    );
    return c.json({ post: publicPost(post, c.get('user').id) }, 201);
  } catch (error) {
    return fail(c, error);
  }
});

savedFits.delete('/:id', async (c) => {
  try {
    await deleteSavedFit(c.get('user').id, c.req.param('id'));
    return c.body(null, 204);
  } catch (error) {
    return fail(c, error);
  }
});

export { savedFits as savedFitRoutes };
