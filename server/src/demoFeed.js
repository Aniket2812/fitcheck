import { readFile } from 'node:fs/promises';

const FEED_FILE = new URL('../seed/feed.json', import.meta.url);

const isoBefore = (now, { ageMinutes = 0, ageDays = 0 }) =>
  new Date(now - (ageMinutes + ageDays * 24 * 60) * 60 * 1000).toISOString();

/**
 * Adds the versioned demo feed to an already-loaded store.
 *
 * IDs are stable, so upgrading or retrying a seed never duplicates records.
 * The caller remains responsible for persisting the changed maps.
 */
export async function seedDemoFeed(db, currentVersion = 0, now = Date.now()) {
  const fixture = JSON.parse(await readFile(FEED_FILE, 'utf8'));
  if (currentVersion >= fixture.version) {
    return { changed: false, version: currentVersion };
  }

  for (const user of fixture.users) {
    const existing = db.users.get(user.id);
    if (existing && !existing.demo) continue;
    const createdAt = isoBefore(now, user);
    db.users.set(user.id, {
      ...existing,
      id: user.id,
      googleId: null,
      email: null,
      name: user.name,
      handle: user.handle,
      bio: user.bio,
      avatarUrl: user.avatarUrl,
      googleAvatarUrl: null,
      modelPhotoUrl: null,
      modelPhotos: [],
      createdAt,
      updatedAt: createdAt,
      lastSignInAt: null,
      demo: true,
    });
  }

  for (const post of fixture.posts) {
    const existing = db.posts.get(post.id);
    if (existing && !existing.demo) continue;
    const createdAt = isoBefore(now, post);
    const comments = existing?.comments ||
      (post.comments || []).map((comment) => ({
        id: comment.id,
        userId: comment.userId,
        text: comment.text,
        createdAt: isoBefore(now, comment),
      }));
    db.posts.set(post.id, {
      ...existing,
      id: post.id,
      userId: post.userId,
      caption: post.caption,
      imageUrl: post.imageUrl,
      garments: post.garments,
      likeUserIds: existing?.likeUserIds || post.likeUserIds || [],
      comments,
      createdAt: existing?.createdAt || createdAt,
      updatedAt: comments.at(-1)?.createdAt || createdAt,
      demo: true,
    });
  }

  return { changed: true, version: fixture.version };
}
