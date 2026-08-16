import { Hono } from 'hono';

import { googleConfigured, verifyGoogleIdToken } from '../google.js';
import {
  createSession,
  deleteSession,
  findUserByHandle,
  privateProfile,
  ProfileError,
  publicProfile,
  updateUser,
  upsertGoogleUser,
  userForToken,
} from '../store.js';

const auth = new Hono();

/** Reads the bearer token off a request. Returns null when absent. */
export function bearerToken(c) {
  const header = c.req.header('authorization') || '';
  const [scheme, token] = header.split(' ');
  return scheme?.toLowerCase() === 'bearer' && token ? token : null;
}

/**
 * Rejects requests without a live session. Downstream handlers read the user
 * with `c.get('user')`.
 */
export async function requireUser(c, next) {
  const token = bearerToken(c);
  const user = userForToken(token);
  if (!user) return c.json({ error: 'Sign in to continue.' }, 401);

  c.set('user', user);
  c.set('token', token);
  await next();
}

/**
 * POST /api/auth/google  { idToken }
 *
 * Exchanges a Google ID token for a fitterest session. Sign-up and sign-in are
 * the same call — there is no separate registration step, because Google has
 * already told us who this is.
 */
auth.post('/google', async (c) => {
  let body;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: 'Send a JSON body with an idToken.' }, 400);
  }

  let identity;
  try {
    identity = await verifyGoogleIdToken(body?.idToken);
  } catch (error) {
    return c.json({ error: error.message }, error.status || 401);
  }

  const user = await upsertGoogleUser(identity);
  const session = await createSession(user.id);

  return c.json({
    token: session.token,
    expiresAt: session.expiresAt,
    user: privateProfile(user),
  });
});

/** POST /api/auth/signout — drops this device's session only. */
auth.post('/signout', requireUser, async (c) => {
  await deleteSession(c.get('token'));
  return c.json({ ok: true });
});

/** GET /api/auth/config — lets the client tell dev mode from the real thing. */
auth.get('/config', (c) => c.json({ google: googleConfigured ? 'configured' : 'dev' }));

const me = new Hono();

me.use('/*', requireUser);

/** GET /api/me — the signed-in user's own profile. */
me.get('/', (c) => c.json({ user: privateProfile(c.get('user')) }));

/** PATCH /api/me  { name?, handle?, bio?, avatarUrl?, modelPhotoUrl? } */
me.patch('/', async (c) => {
  let patch;
  try {
    patch = await c.req.json();
  } catch {
    return c.json({ error: 'Send a JSON body with the fields to change.' }, 400);
  }

  try {
    const user = await updateUser(c.get('user').id, patch);
    return c.json({ user: privateProfile(user) });
  } catch (error) {
    if (error instanceof ProfileError) return c.json({ error: error.message }, error.status);
    throw error;
  }
});

const users = new Hono();

/** GET /api/users/:handle — the public profile behind a handle. */
users.get('/:handle', (c) => {
  const user = findUserByHandle(c.req.param('handle'));
  if (!user) return c.json({ error: 'No such profile.' }, 404);
  return c.json({ user: publicProfile(user) });
});

export { auth as authRoutes, me as meRoutes, users as userRoutes };
