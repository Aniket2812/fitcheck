import { Hono } from 'hono';

import { MediaError, saveDataImage, saveUploadedImage } from '../media.js';
import {
  addPostComment,
  createPost,
  deletePost,
  findPostById,
  listPosts,
  PostError,
  publicPost,
  togglePostLike,
  userForToken,
} from '../store.js';
import { bearerToken, requireUser } from './auth.js';

const posts = new Hono();

function viewer(c) {
  return userForToken(bearerToken(c));
}

function errorResponse(c, error) {
  if (error instanceof PostError || error instanceof MediaError) {
    return c.json({ error: error.message }, error.status);
  }
  throw error;
}

async function parseCreateRequest(c) {
  const contentType = c.req.header('content-type') || '';
  if (contentType.includes('multipart/form-data')) {
    const form = await c.req.formData();
    let garments;
    try {
      garments = JSON.parse(String(form.get('garments') || '[]'));
    } catch {
      throw new PostError('Garment tags are malformed.');
    }
    return {
      caption: String(form.get('caption') || ''),
      imageUrl: await saveUploadedImage(form.get('image'), 'post'),
      garments,
    };
  }
  return c.req.json();
}

async function persistGarmentCutouts(garments) {
  if (!Array.isArray(garments)) return garments;
  return Promise.all(
    garments.map(async (garment) => {
      const productImageUrls = Array.isArray(garment.productImageUrls)
        ? await Promise.all(
            garment.productImageUrls.slice(0, 5).map((source) =>
              String(source || '').startsWith('data:image/')
                ? saveDataImage(source, 'product')
                : source,
            ),
          )
        : garment.productImageUrls;
      return {
        ...garment,
        productImageUrls,
        imageUrl: String(garment.imageUrl || garment.image || '').startsWith('data:image/')
          ? await saveDataImage(garment.imageUrl || garment.image, 'garment')
          : garment.imageUrl || garment.image,
      };
    }),
  );
}

posts.get('/', (c) => {
  const user = viewer(c);
  return c.json({
    posts: listPosts()
      .map((post) => publicPost(post, user?.id))
      .filter(Boolean),
  });
});

posts.post('/', requireUser, async (c) => {
  try {
    const input = await parseCreateRequest(c);
    input.garments = await persistGarmentCutouts(input.garments);
    const post = await createPost(c.get('user').id, input);
    return c.json({ post: publicPost(post, c.get('user').id) }, 201);
  } catch (error) {
    return errorResponse(c, error);
  }
});

posts.get('/:id', (c) => {
  const post = findPostById(c.req.param('id'));
  if (!post) return c.json({ error: 'No such post.' }, 404);
  return c.json({ post: publicPost(post, viewer(c)?.id) });
});

posts.post('/:id/like', requireUser, async (c) => {
  try {
    const { post, liked } = await togglePostLike(c.req.param('id'), c.get('user').id);
    return c.json({ liked, post: publicPost(post, c.get('user').id) });
  } catch (error) {
    return errorResponse(c, error);
  }
});

posts.post('/:id/comments', requireUser, async (c) => {
  try {
    const body = await c.req.json();
    await addPostComment(c.req.param('id'), c.get('user').id, body?.text);
    const post = findPostById(c.req.param('id'));
    return c.json({ post: publicPost(post, c.get('user').id) }, 201);
  } catch (error) {
    return errorResponse(c, error);
  }
});

posts.delete('/:id', requireUser, async (c) => {
  try {
    await deletePost(c.req.param('id'), c.get('user').id);
    return c.body(null, 204);
  } catch (error) {
    return errorResponse(c, error);
  }
});

export { posts as postRoutes };
