/**
 * Google ID token verification.
 *
 * The client does the OAuth dance and sends us the resulting ID token; this
 * module's only job is proving that token really came from Google and really
 * names our app. Verification goes through Google's tokeninfo endpoint rather
 * than local JWKS validation — one network hop per sign-in, no crypto
 * dependency, and it can't drift out of sync with Google's signing keys.
 *
 * Set GOOGLE_CLIENT_ID before shipping. Without it the server runs in dev
 * mode, where it trusts an unsigned identity from the client so the rest of
 * the profile system is usable before OAuth is wired up.
 */

const TOKENINFO_URL = 'https://oauth2.googleapis.com/tokeninfo';

// Google mints tokens for several client ids of the same project (iOS,
// Android, web). Accept the whole comma-separated set.
const AUDIENCES = (process.env.GOOGLE_CLIENT_ID || '')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

const VALID_ISSUERS = new Set(['accounts.google.com', 'https://accounts.google.com']);

export const googleConfigured = AUDIENCES.length > 0;

class AuthError extends Error {
  constructor(message, status = 401) {
    super(message);
    this.status = status;
  }
}

/**
 * @param {string} idToken
 * @returns {Promise<{ googleId: string, email: string|null, name: string|null, picture: string|null }>}
 */
export async function verifyGoogleIdToken(idToken) {
  if (!idToken || typeof idToken !== 'string') {
    throw new AuthError('Missing Google ID token.', 400);
  }

  if (!googleConfigured) return devIdentity(idToken);

  let response;
  try {
    response = await fetch(`${TOKENINFO_URL}?id_token=${encodeURIComponent(idToken)}`);
  } catch {
    throw new AuthError('Could not reach Google to verify that sign-in.', 503);
  }

  if (!response.ok) throw new AuthError('That Google sign-in is not valid.');

  const claims = await response.json().catch(() => null);
  if (!claims?.sub) throw new AuthError('That Google sign-in is not valid.');

  // tokeninfo checks the signature and expiry for us; audience and issuer are
  // ours to check — a validly-signed token for someone else's app is still a
  // token for someone else's app.
  if (!AUDIENCES.includes(claims.aud)) {
    throw new AuthError('That sign-in was issued for a different app.');
  }
  if (!VALID_ISSUERS.has(claims.iss)) {
    throw new AuthError('That sign-in came from an unexpected issuer.');
  }
  if (claims.email && claims.email_verified === 'false') {
    throw new AuthError('That Google account has no verified email.');
  }

  return {
    googleId: claims.sub,
    email: claims.email || null,
    name: claims.name || null,
    picture: claims.picture || null,
  };
}

/**
 * Dev-only stand-in. The client sends `dev:<id>:<email>:<name>` and we take it
 * at face value. Guarded on GOOGLE_CLIENT_ID being unset, so configuring the
 * real client id turns this path off — there is no flag to forget to flip.
 */
function devIdentity(idToken) {
  if (!idToken.startsWith('dev:')) {
    throw new AuthError(
      'This server has no GOOGLE_CLIENT_ID configured, so it only accepts dev sign-ins.',
      503,
    );
  }

  const [, id, email, ...rest] = idToken.split(':');
  const name = rest.join(':') || 'Demo user';
  console.warn('[auth] dev sign-in accepted — set GOOGLE_CLIENT_ID to verify real tokens');

  return {
    googleId: `dev-${id || 'local'}`,
    email: email || null,
    name,
    picture: null,
  };
}
