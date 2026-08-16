import { Hono } from 'hono';

import {
  addCollectionItem,
  CollectionError,
  createCollection,
  deleteCollectionItem,
  listCollections,
} from '../collectionsStore.js';
import { requireUser } from './auth.js';

const collections = new Hono();
collections.use('/*', requireUser);

function fail(c, error) {
  if (error instanceof CollectionError) return c.json({ error: error.message }, error.status);
  throw error;
}

collections.get('/', async (c) => {
  try {
    return c.json({ collections: await listCollections(c.get('user').id) });
  } catch (error) {
    return fail(c, error);
  }
});

collections.post('/', async (c) => {
  try {
    const body = await c.req.json();
    const collection = await createCollection(c.get('user').id, body?.name);
    return c.json({ collection }, 201);
  } catch (error) {
    return fail(c, error);
  }
});

collections.post('/:collectionId/items', async (c) => {
  try {
    const body = await c.req.json();
    const result = await addCollectionItem(
      c.get('user').id,
      c.req.param('collectionId'),
      body,
    );
    return c.json(result, result.created ? 201 : 200);
  } catch (error) {
    return fail(c, error);
  }
});

collections.delete('/:collectionId/items/:itemId', async (c) => {
  try {
    await deleteCollectionItem(
      c.get('user').id,
      c.req.param('collectionId'),
      c.req.param('itemId'),
    );
    return c.body(null, 204);
  } catch (error) {
    return fail(c, error);
  }
});

export { collections as collectionRoutes };
