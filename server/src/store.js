import { randomUUID, randomBytes } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { seedDemoFeed } from './demoFeed.js';

/**
 * User + session storage, backed by a single JSON file.
 *
 * Deliberately not a database: the whole set fits in memory, reads are
 * synchronous against that copy, and writes are mirrored to disk so a server
 * restart doesn't sign everyone out mid-demo. The exported surface is the
 * shape a real repository would have, so swapping in Postgres later means
 * rewriting this file and nothing else.
 */

const HERE = dirname(fileURLToPath(import.meta.url));
const DATA_FILE = process.env.DATA_FILE || join(HERE, '..', 'data', 'users.json');

const SESSION_TTL_MS = 90 * 24 * 60 * 60 * 1000; // 90 days

// Sessions renew on use once half their life has gone, so someone who opens
// the app regularly is never signed out on a fixed clock — only 30 days of
// actual silence ends a session. Renewing on every request instead would mean
// a disk write per call for no extra benefit.
const SESSION_RENEW_AFTER_MS = SESSION_TTL_MS / 2;

/** @type {{ users: Map<string, object>, sessions: Map<string, object>, posts: Map<string, object>, savedFits: Map<string, object>, demoFeedVersion: number }} */
const db = {
  users: new Map(),
  sessions: new Map(),
  posts: new Map(),
  savedFits: new Map(),
  demoFeedVersion: 0,
};

let writing = null;
let writeAgain = false;

async function flush() {
  // Coalesce concurrent mutations into one pending write, then one follow-up
  // if anything changed while that write was in flight.
  if (writing) {
    writeAgain = true;
    return writing;
  }

  writing = (async () => {
    const payload = JSON.stringify(
      {
        users: [...db.users.values()],
        sessions: [...db.sessions.values()],
        posts: [...db.posts.values()],
        savedFits: [...db.savedFits.values()],
        demoFeedVersion: db.demoFeedVersion,
      },
      null,
      2,
    );

    await mkdir(dirname(DATA_FILE), { recursive: true });
    // Write-then-rename so a crash mid-write can't leave a truncated file.
    const temp = `${DATA_FILE}.${process.pid}.tmp`;
    await writeFile(temp, payload, 'utf8');
    await rename(temp, DATA_FILE);
  })();

  try {
    await writing;
  } finally {
    writing = null;
  }

  if (writeAgain) {
    writeAgain = false;
    await flush();
  }
}

export async function loadStore() {
  let parsed = {};
  try {
    parsed = JSON.parse(await readFile(DATA_FILE, 'utf8'));
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    // A first run starts from empty maps and is seeded below when enabled.
  }

  for (const user of parsed.users || []) {
    if (!Array.isArray(user.modelPhotos)) {
      user.modelPhotos = user.modelPhotoUrl
        ? [
            {
              id: `legacy-${user.id}`,
              imageUrl: user.modelPhotoUrl,
              label: 'My photo',
              isPrimary: true,
              createdAt: user.updatedAt || user.createdAt,
            },
          ]
        : [];
    }
    db.users.set(user.id, user);
  }

  const now = Date.now();
  for (const session of parsed.sessions || []) {
    if (Date.parse(session.expiresAt) > now) db.sessions.set(session.token, session);
  }
  for (const post of parsed.posts || []) db.posts.set(post.id, post);
  for (const fit of parsed.savedFits || []) db.savedFits.set(fit.id, fit);
  db.demoFeedVersion = Number(parsed.demoFeedVersion || 0);

  if (process.env.SEED_DEMO_DATA !== 'false') {
    const seeded = await seedDemoFeed(db, db.demoFeedVersion, now);
    db.demoFeedVersion = seeded.version;
    if (seeded.changed) await flush();
  }
}

// ─────────────────────────────────────────────────────────────
// Handles
// ─────────────────────────────────────────────────────────────

export const HANDLE_PATTERN = /^[a-z0-9_]{3,20}$/;

/** Normalises user input so `@Mohit ` and `mohit` are the same handle. */
export function normaliseHandle(value) {
  return String(value || '')
    .trim()
    .replace(/^@/, '')
    .toLowerCase();
}

function handleTaken(handle, exceptUserId) {
  for (const user of db.users.values()) {
    if (user.handle === handle && user.id !== exceptUserId) return true;
  }
  return false;
}

/** Derives a free handle from a Google display name or email local part. */
function suggestHandle(seed) {
  const base = String(seed || '')
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, '')
    .slice(0, 16) || 'friend';

  const padded = base.length >= 3 ? base : `${base}fit`;
  if (!handleTaken(padded)) return padded;

  // Suffix rather than reject: sign-in must never fail on a name collision.
  for (let i = 2; i < 1000; i += 1) {
    const candidate = `${padded.slice(0, 20 - String(i).length)}${i}`;
    if (!handleTaken(candidate)) return candidate;
  }
  return `${padded.slice(0, 12)}${randomBytes(3).toString('hex')}`;
}

// ─────────────────────────────────────────────────────────────
// Users
// ─────────────────────────────────────────────────────────────

export function findUserById(id) {
  return db.users.get(id) || null;
}

export function findUserByHandle(handle) {
  const wanted = normaliseHandle(handle);
  for (const user of db.users.values()) {
    if (user.handle === wanted) return user;
  }
  return null;
}

export function findUserByGoogleId(googleId) {
  for (const user of db.users.values()) {
    if (user.googleId === googleId) return user;
  }
  return null;
}

function findUserByEmail(email) {
  const wanted = String(email || '').toLowerCase();
  if (!wanted) return null;
  for (const user of db.users.values()) {
    if (user.email === wanted) return user;
  }
  return null;
}

/**
 * Finds the account behind a verified Google identity, creating it on first
 * sign-in. Matching on `googleId` first and email second means a user who
 * somehow arrives with a new Google subject keeps their existing closet.
 */
export async function upsertGoogleUser({ googleId, email, name, picture }) {
  const existing = findUserByGoogleId(googleId) || findUserByEmail(email);

  if (existing) {
    existing.googleId = googleId;
    if (email) existing.email = email.toLowerCase();
    // Google's picture URL rotates; the profile fields the user edited are
    // never overwritten from the provider.
    if (picture) existing.googleAvatarUrl = picture;
    existing.lastSignInAt = new Date().toISOString();
    existing.updatedAt = existing.lastSignInAt;
    await flush();
    return existing;
  }

  const now = new Date().toISOString();
  const user = {
    id: randomUUID(),
    googleId,
    email: email ? email.toLowerCase() : null,
    name: name || 'New member',
    handle: suggestHandle(name || (email || '').split('@')[0]),
    bio: '',
    // Set by the user; falls back to the Google picture when empty.
    avatarUrl: null,
    googleAvatarUrl: picture || null,
    // The full-body shot every try-on renders onto. Null until they upload one.
    modelPhotoUrl: null,
    modelPhotos: [],
    createdAt: now,
    updatedAt: now,
    lastSignInAt: now,
  };

  db.users.set(user.id, user);
  await flush();
  return user;
}

export class ProfileError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

const FIELD_LIMITS = { name: 40, bio: 160 };

/** Applies a partial profile edit. Unknown keys are ignored, not rejected. */
export async function updateUser(userId, patch) {
  const user = db.users.get(userId);
  if (!user) throw new ProfileError('No such account.', 404);

  if ('handle' in patch) {
    const handle = normaliseHandle(patch.handle);
    if (!HANDLE_PATTERN.test(handle)) {
      throw new ProfileError('Handles are 3–20 characters: letters, numbers, underscores.');
    }
    if (handleTaken(handle, userId)) {
      throw new ProfileError('That handle is taken.', 409);
    }
    user.handle = handle;
  }

  for (const field of ['name', 'bio']) {
    if (!(field in patch)) continue;
    const value = String(patch[field] ?? '').trim();
    if (value.length > FIELD_LIMITS[field]) {
      throw new ProfileError(`${field === 'name' ? 'Name' : 'Bio'} is too long.`);
    }
    if (field === 'name' && !value) throw new ProfileError('Name cannot be empty.');
    user[field] = value;
  }

  for (const field of ['avatarUrl', 'modelPhotoUrl']) {
    if (!(field in patch)) continue;
    user[field] = patch[field] ? String(patch[field]) : null;
  }

  user.updatedAt = new Date().toISOString();
  await flush();
  return user;
}

function projectedModelPhoto(photo) {
  return {
    id: photo.id,
    imageUrl: photo.imageUrl,
    label: photo.label,
    isPrimary: Boolean(photo.isPrimary),
    width: photo.width || null,
    height: photo.height || null,
    youCamReady: true,
    createdAt: photo.createdAt,
  };
}

export function listModelPhotos(userId) {
  const user = db.users.get(userId);
  if (!user) throw new ProfileError('No such account.', 404);
  return (user.modelPhotos || []).map(projectedModelPhoto);
}

export function findModelPhoto(userId, photoId) {
  const user = db.users.get(userId);
  return user?.modelPhotos?.find((photo) => photo.id === photoId) || null;
}

export async function addModelPhoto(userId, imageUrl, label, metadata = {}) {
  const user = db.users.get(userId);
  if (!user) throw new ProfileError('No such account.', 404);
  const photos = user.modelPhotos || [];
  if (photos.length >= 12) {
    throw new ProfileError('You can keep up to 12 full-body photos.', 409);
  }
  const cleanLabel = String(label || '').trim();
  if (cleanLabel.length > 40) throw new ProfileError('Photo labels can be at most 40 characters.');
  const photo = {
    id: randomUUID(),
    imageUrl,
    label: cleanLabel || `Photo ${photos.length + 1}`,
    isPrimary: photos.length === 0,
    width: Number(metadata.width) || null,
    height: Number(metadata.height) || null,
    createdAt: new Date().toISOString(),
  };
  user.modelPhotos = [...photos, photo];
  if (photo.isPrimary) user.modelPhotoUrl = imageUrl;
  user.updatedAt = photo.createdAt;
  await flush();
  return projectedModelPhoto(photo);
}

export async function setPrimaryModelPhoto(userId, photoId) {
  const user = db.users.get(userId);
  const selected = user?.modelPhotos?.find((photo) => photo.id === photoId);
  if (!user || !selected) throw new ProfileError('No such full-body photo.', 404);
  for (const photo of user.modelPhotos) photo.isPrimary = photo.id === photoId;
  user.modelPhotoUrl = selected.imageUrl;
  user.updatedAt = new Date().toISOString();
  await flush();
  return projectedModelPhoto(selected);
}

export async function deleteModelPhoto(userId, photoId) {
  const user = db.users.get(userId);
  const photo = user?.modelPhotos?.find((item) => item.id === photoId);
  if (!user || !photo) throw new ProfileError('No such full-body photo.', 404);
  user.modelPhotos = user.modelPhotos.filter((item) => item.id !== photoId);
  if (photo.isPrimary && user.modelPhotos.length) user.modelPhotos[0].isPrimary = true;
  user.modelPhotoUrl = user.modelPhotos.find((item) => item.isPrimary)?.imageUrl || null;
  user.updatedAt = new Date().toISOString();
  await flush();
}

// ─────────────────────────────────────────────────────────────
// Sessions
// ─────────────────────────────────────────────────────────────

export async function createSession(userId) {
  const session = {
    token: randomBytes(32).toString('base64url'),
    userId,
    createdAt: new Date().toISOString(),
    expiresAt: new Date(Date.now() + SESSION_TTL_MS).toISOString(),
  };
  db.sessions.set(session.token, session);
  await flush();
  return session;
}

/** Returns the user behind a bearer token, or null if it is unknown/expired. */
export function userForToken(token) {
  const session = token ? db.sessions.get(token) : null;
  if (!session) return null;

  const now = Date.now();
  if (Date.parse(session.expiresAt) <= now) {
    db.sessions.delete(token);
    void flush();
    return null;
  }

  const user = db.users.get(session.userId) || null;
  // Only slide the window for a session that still resolves to a real user;
  // extending one whose account is gone would keep a dead token alive.
  if (user && Date.parse(session.expiresAt) - now < SESSION_TTL_MS - SESSION_RENEW_AFTER_MS) {
    session.expiresAt = new Date(now + SESSION_TTL_MS).toISOString();
    void flush();
  }

  return user;
}

export async function deleteSession(token) {
  if (db.sessions.delete(token)) await flush();
}

// ─────────────────────────────────────────────────────────────
// Social posts
// ─────────────────────────────────────────────────────────────

export class PostError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

const POST_LIMITS = { caption: 500, comment: 300, garments: 12 };

const clampUnit = (value, fallback) => {
  const number = Number(value);
  return Number.isFinite(number) ? Math.min(1, Math.max(0, number)) : fallback;
};

function cleanGarment(garment, index) {
  const title = String(garment?.title || '').trim();
  const imageUrl = String(garment?.imageUrl || garment?.image || '').trim();
  const buyUrl = String(garment?.buyUrl || garment?.pageUrl || '').trim();
  if (!title || !imageUrl || !buyUrl) {
    throw new PostError(`Garment ${index + 1} needs a title, cutout image, and buying link.`);
  }
  try {
    const parsed = new URL(buyUrl);
    if (!['http:', 'https:'].includes(parsed.protocol)) throw new Error();
  } catch {
    throw new PostError(`Garment ${index + 1} has an invalid buying link.`);
  }
  const gallery = (Array.isArray(garment?.productImageUrls)
    ? garment.productImageUrls
    : [garment?.originalImageUrl || imageUrl]
  )
    .map((value) => String(value || '').trim())
    .filter(Boolean)
    .slice(0, 5);
  if (!gallery.length) gallery.push(imageUrl);
  while (gallery.length < 4) gallery.push(gallery.at(-1));

  return {
    id: garment.id || randomUUID(),
    title: title.slice(0, 120),
    brand: garment.brand ? String(garment.brand).slice(0, 80) : null,
    price: garment.price ? String(garment.price).slice(0, 80) : null,
    imageUrl,
    originalImageUrl: garment.originalImageUrl ? String(garment.originalImageUrl) : null,
    productImageUrls: gallery,
    buyUrl,
    category: garment.category ? String(garment.category).slice(0, 40) : null,
    x: clampUnit(garment.x, 0.5),
    y: clampUnit(garment.y, 0.5),
  };
}

export async function createPost(
  userId,
  {
    caption,
    imageUrl,
    garments,
    backgroundStyle = 'original',
    posePreserved = true,
    backgroundTaskId = null,
  },
) {
  if (!db.users.has(userId)) throw new PostError('No such account.', 404);
  const cleanCaption = String(caption || '').trim();
  if (cleanCaption.length > POST_LIMITS.caption) {
    throw new PostError(`Captions can be at most ${POST_LIMITS.caption} characters.`);
  }
  if (!imageUrl) throw new PostError('Choose an outfit photo.');
  if (!Array.isArray(garments) || garments.length === 0) {
    throw new PostError('Tag at least one garment before posting.');
  }
  if (garments.length > POST_LIMITS.garments) {
    throw new PostError(`A post can contain at most ${POST_LIMITS.garments} garments.`);
  }

  const now = new Date().toISOString();
  const post = {
    id: randomUUID(),
    userId,
    caption: cleanCaption,
    imageUrl: String(imageUrl),
    backgroundStyle: String(backgroundStyle),
    posePreserved: posePreserved !== false,
    backgroundTaskId: backgroundTaskId ? String(backgroundTaskId) : null,
    garments: garments.map(cleanGarment),
    likeUserIds: [],
    comments: [],
    createdAt: now,
    updatedAt: now,
  };
  db.posts.set(post.id, post);
  await flush();
  return post;
}

export function findPostById(id) {
  return db.posts.get(id) || null;
}

export function listPosts() {
  return [...db.posts.values()].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

export async function togglePostLike(postId, userId) {
  const post = db.posts.get(postId);
  if (!post) throw new PostError('No such post.', 404);
  const likes = new Set(post.likeUserIds || []);
  const liked = !likes.has(userId);
  if (liked) likes.add(userId);
  else likes.delete(userId);
  post.likeUserIds = [...likes];
  post.updatedAt = new Date().toISOString();
  await flush();
  return { post, liked };
}

export async function addPostComment(postId, userId, text) {
  const post = db.posts.get(postId);
  if (!post) throw new PostError('No such post.', 404);
  const cleanText = String(text || '').trim();
  if (!cleanText) throw new PostError('Write a comment first.');
  if (cleanText.length > POST_LIMITS.comment) {
    throw new PostError(`Comments can be at most ${POST_LIMITS.comment} characters.`);
  }
  const comment = {
    id: randomUUID(),
    userId,
    text: cleanText,
    createdAt: new Date().toISOString(),
  };
  post.comments = [...(post.comments || []), comment];
  post.updatedAt = comment.createdAt;
  await flush();
  return comment;
}

export async function deletePost(postId, userId) {
  const post = db.posts.get(postId);
  if (!post) throw new PostError('No such post.', 404);
  if (post.userId !== userId) throw new PostError('You can only delete your own posts.', 403);
  db.posts.delete(postId);
  await flush();
}

// ─────────────────────────────────────────────────────────────
// Private saved fits / post drafts
// ─────────────────────────────────────────────────────────────

export class SavedFitError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

function projectSavedFit(fit) {
  return {
    id: fit.id,
    caption: fit.caption,
    imageUrl: fit.imageUrl,
    garments: fit.garments,
    modelPhotoId: fit.modelPhotoId || null,
    backgroundStyle: 'original',
    posePreserved: true,
    createdAt: fit.createdAt,
    updatedAt: fit.updatedAt,
  };
}

function ownSavedFit(userId, fitId) {
  const fit = db.savedFits.get(fitId);
  if (!fit || fit.userId !== userId) {
    throw new SavedFitError('No such saved fit.', 404);
  }
  return fit;
}

export function listSavedFits(userId) {
  if (!db.users.has(userId)) throw new SavedFitError('No such account.', 404);
  return [...db.savedFits.values()]
    .filter((fit) => fit.userId === userId)
    .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
    .map(projectSavedFit);
}

export function getSavedFit(userId, fitId) {
  return projectSavedFit(ownSavedFit(userId, fitId));
}

export async function createSavedFit(
  userId,
  { caption, imageUrl, garments, modelPhotoId = null },
) {
  const user = db.users.get(userId);
  if (!user) throw new SavedFitError('No such account.', 404);
  if (!imageUrl) throw new SavedFitError('Generate the outfit preview before saving this fit.');
  if (!Array.isArray(garments) || garments.length === 0) {
    throw new SavedFitError('Choose at least one collection item.');
  }
  if (garments.length > POST_LIMITS.garments) {
    throw new SavedFitError(`A saved fit can contain at most ${POST_LIMITS.garments} garments.`);
  }
  const cleanCaption = String(caption || '').trim();
  if (cleanCaption.length > POST_LIMITS.caption) {
    throw new SavedFitError(`Captions can be at most ${POST_LIMITS.caption} characters.`);
  }
  if (modelPhotoId && !(user.modelPhotos || []).some((photo) => photo.id === modelPhotoId)) {
    throw new SavedFitError('The selected full-body photo no longer exists.', 409);
  }
  if ([...db.savedFits.values()].filter((fit) => fit.userId === userId).length >= 30) {
    throw new SavedFitError('You can keep up to 30 saved fits.', 409);
  }

  const now = new Date().toISOString();
  const fit = {
    id: randomUUID(),
    userId,
    caption: cleanCaption,
    imageUrl: String(imageUrl),
    garments: garments.map(cleanGarment),
    modelPhotoId: modelPhotoId ? String(modelPhotoId) : null,
    createdAt: now,
    updatedAt: now,
  };
  db.savedFits.set(fit.id, fit);
  await flush();
  return projectSavedFit(fit);
}

export async function deleteSavedFit(userId, fitId) {
  ownSavedFit(userId, fitId);
  db.savedFits.delete(fitId);
  await flush();
}

export async function publishSavedFit(
  userId,
  fitId,
  caption,
  {
    imageUrl,
    backgroundStyle = 'original',
    posePreserved = true,
    backgroundTaskId = null,
  } = {},
) {
  const fit = ownSavedFit(userId, fitId);
  const post = await createPost(userId, {
    caption: caption == null ? fit.caption : caption,
    imageUrl: imageUrl || fit.imageUrl,
    garments: fit.garments,
    backgroundStyle,
    posePreserved,
    backgroundTaskId,
  });
  db.savedFits.delete(fitId);
  await flush();
  return post;
}

// ─────────────────────────────────────────────────────────────
// Projections — never hand the raw record to a client.
// ─────────────────────────────────────────────────────────────

/** What a user may see about themselves. */
export function privateProfile(user) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    handle: user.handle,
    bio: user.bio,
    avatarUrl: user.avatarUrl || user.googleAvatarUrl || null,
    modelPhotoUrl: user.modelPhotoUrl,
    modelPhotos: (user.modelPhotos || []).map(projectedModelPhoto),
    createdAt: user.createdAt,
  };
}

/** What anyone may see about a user. Email and model photo stay private. */
export function publicProfile(user) {
  return {
    id: user.id,
    name: user.name,
    handle: user.handle,
    bio: user.bio,
    avatarUrl: user.avatarUrl || user.googleAvatarUrl || null,
    createdAt: user.createdAt,
  };
}

export function publicPost(post, viewerId = null) {
  const author = db.users.get(post.userId);
  if (!author) return null;
  return {
    id: post.id,
    caption: post.caption,
    imageUrl: post.imageUrl,
    backgroundStyle: post.backgroundStyle || 'compete:studio',
    posePreserved: post.posePreserved !== false,
    garments: post.garments || [],
    author: publicProfile(author),
    likeCount: (post.likeUserIds || []).length,
    likedByMe: viewerId ? (post.likeUserIds || []).includes(viewerId) : false,
    comments: (post.comments || []).map((comment) => ({
      id: comment.id,
      text: comment.text,
      createdAt: comment.createdAt,
      author: publicProfile(db.users.get(comment.userId) || author),
    })),
    commentCount: (post.comments || []).length,
    createdAt: post.createdAt,
  };
}
