import { Hono } from 'hono';

import { MediaError, saveModelPhoto } from '../media.js';
import {
  addModelPhoto,
  deleteModelPhoto,
  listModelPhotos,
  ProfileError,
  setPrimaryModelPhoto,
} from '../store.js';
import { requireUser } from './auth.js';

const modelPhotos = new Hono();

modelPhotos.use('/*', requireUser);

modelPhotos.get('/', (c) =>
  c.json({ photos: listModelPhotos(c.get('user').id) }),
);

modelPhotos.post('/', async (c) => {
  try {
    const body = await c.req.parseBody();
    const saved = await saveModelPhoto(body.image);
    const photo = await addModelPhoto(
      c.get('user').id,
      saved.imageUrl,
      body.label,
      { width: saved.width, height: saved.height },
    );
    return c.json({ photo }, 201);
  } catch (error) {
    if (error instanceof MediaError || error instanceof ProfileError) {
      return c.json({ error: error.message }, error.status);
    }
    throw error;
  }
});

modelPhotos.post('/:id/primary', async (c) => {
  try {
    const photo = await setPrimaryModelPhoto(
      c.get('user').id,
      c.req.param('id'),
    );
    return c.json({ photo });
  } catch (error) {
    if (error instanceof ProfileError) {
      return c.json({ error: error.message }, error.status);
    }
    throw error;
  }
});

modelPhotos.delete('/:id', async (c) => {
  try {
    await deleteModelPhoto(c.get('user').id, c.req.param('id'));
    return c.body(null, 204);
  } catch (error) {
    if (error instanceof ProfileError) {
      return c.json({ error: error.message }, error.status);
    }
    throw error;
  }
});

export { modelPhotos as modelPhotoRoutes };
