/**
 * Everything between "the user hit share in an app" and "we have a URL worth
 * fetching". Share sheets hand over a sentence, a shortener, or a deep link —
 * rarely the canonical product URL.
 */

const URL_IN_TEXT = /(https?:\/\/[^\s<>"')\]]+)/i;
const BARE_HOST = /(?:^|\s)((?:www\.)?[a-z0-9-]+(?:\.[a-z0-9-]+)+\/[^\s<>"')\]]*)/i;

/** utm_* and friends. Deliberately a denylist — variant params carry meaning. */
const TRACKING_PARAMS = new Set([
  'gclid',
  'fbclid',
  'msclkid',
  'ttclid',
  'igshid',
  'twclid',
  'yclid',
  'dclid',
  'srsltid',
  'irclickid',
  'irgwc',
  'sharedid',
  'ranmid',
  'raneaid',
  'ransiteid',
  'cjevent',
  'affid',
  'affextparam1',
  'affextparam2',
  'cmpid',
  'camp',
  'creative',
  'creativeasin',
  'linkcode',
  'linkid',
  'ascsubtag',
  'psc',
  'smid',
  'pd_rd_i',
  'pd_rd_r',
  'pd_rd_w',
  'pd_rd_wg',
  'pf_rd_i',
  'pf_rd_m',
  'pf_rd_p',
  'pf_rd_r',
  'pf_rd_s',
  'pf_rd_t',
  '_branch_match_id',
  '_branch_referrer',
  'sharer',
  'share_from',
  'shared_from',
  'source',
  'src',
  'referrer',
  'cid',
  'scid',
  'sc_channel',
  'mc_cid',
  'mc_eid',
]);

const isTracking = (key) => {
  const k = key.toLowerCase();
  return k.startsWith('utm_') || TRACKING_PARAMS.has(k);
};

/**
 * Hosts that only ever serve a redirect. We resolve these before deciding
 * whether the destination needs the unblocker, since the shortener itself
 * tells us nothing about the retailer behind it.
 */
const SHORTENERS = new Set([
  'a.co',
  'amzn.to',
  'amzn.eu',
  'amzn.asia',
  'bit.ly',
  'tinyurl.com',
  'shorturl.at',
  't.co',
  'ow.ly',
  'buff.ly',
  'rb.gy',
  'cutt.ly',
  'lnk.to',
  'go.shop.app',
  'shop.app',
  'spr.ly',
  'trib.al',
  'zlnk.com',
  's.shein.com',
  'shein.top',
  // India — these are what the app share sheets actually hand over.
  'myntr.it',
  'dl.flipkart.com',
  'fkrt.cc',
  'fkrt.it',
  'amzn.in',
  'ajio.me',
  'nike.onelink.me',
  'asos.onelink.me',
  'hm.onelink.me',
  'zara.onelink.me',
  'onelink.me',
  'app.link',
  'go.skimresources.com',
  'linksynergy.com',
  'click.linksynergy.com',
  'prf.hn',
  'shareasale.com',
  'redirect.viglink.com',
]);

const stripWww = (host) => host.replace(/^www\./, '');

/** True for the redirect hosts above, plus anything under a *.app.link subdomain. */
export function isShortener(url) {
  try {
    const host = stripWww(new URL(url).hostname.toLowerCase());
    return SHORTENERS.has(host) || host.endsWith('.app.link') || host.endsWith('.onelink.me');
  } catch {
    return false;
  }
}

/**
 * Deep links (`myntra://`, `zara://`, `intent://…#Intent;…`) sometimes reach us
 * from Android share sheets. The https target is usually right there in the
 * payload, so dig it out rather than rejecting the paste.
 */
function fromDeepLink(text) {
  const intent = text.match(/^intent:\/\/([^#]+)#Intent;(.*)$/i);
  if (intent) {
    const scheme = intent[2].match(/scheme=([a-z]+)/i)?.[1];
    if (scheme === 'http' || scheme === 'https') return `${scheme}://${intent[1]}`;
    return `https://${intent[1]}`;
  }

  const custom = text.match(/^[a-z][a-z0-9+.-]*:\/\/(.+)$/i);
  if (custom && !/^https?:/i.test(text)) {
    const inner = custom[1].match(URL_IN_TEXT);
    if (inner) return inner[1];
  }
  return null;
}

/** Removes tracking noise so two shares of the same product dedupe cleanly. */
export function cleanUrl(url) {
  const parsed = new URL(url);
  for (const key of [...parsed.searchParams.keys()]) {
    if (isTracking(key)) parsed.searchParams.delete(key);
  }
  parsed.hash = '';
  // Trailing "?" reads as a broken link in the UI even though it fetches fine.
  return parsed.toString().replace(/\?$/, '');
}

/**
 * Turns whatever the share sheet produced into an http(s) URL, or throws a
 * message worth showing the user. Does not touch the network.
 */
export function normalizeInput(raw) {
  const text = String(raw ?? '').trim();
  if (!text) {
    throw Object.assign(new Error('Paste a product link to add a piece.'), { status: 400 });
  }

  let candidate = text.match(URL_IN_TEXT)?.[1] || fromDeepLink(text);

  if (!candidate) {
    const bare = text.match(BARE_HOST)?.[1];
    if (bare) candidate = `https://${bare}`;
  }

  if (!candidate) {
    throw Object.assign(new Error('No link in that. Share the product page URL.'), { status: 400 });
  }

  // Share text often runs the URL into trailing punctuation.
  candidate = candidate.replace(/[.,;:!?)\]]+$/, '');

  let parsed;
  try {
    parsed = new URL(candidate);
  } catch {
    throw Object.assign(new Error('That does not look like a link.'), { status: 400 });
  }

  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw Object.assign(new Error('That does not look like a link.'), { status: 400 });
  }

  return cleanUrl(parsed.toString());
}

export const hostOf = (url) => {
  try {
    return stripWww(new URL(url).hostname.toLowerCase());
  } catch {
    return '';
  }
};
