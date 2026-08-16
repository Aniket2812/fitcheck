/**
 * Getting the HTML. Two tiers:
 *
 *   direct   A plain fetch shaped like a real Chrome navigation. Free, fast,
 *            and enough for most retailers.
 *   unblock  Bright Data's Web Unlocker, which handles the ones running
 *            Akamai/PerimeterX/Cloudflare bot defence. Costs money per
 *            request, so it is a fallback, never the default.
 *
 * Hosts marked `unblock: 'always'` in sites.js skip tier one — for those the
 * direct attempt is a guaranteed wasted second.
 */

import { siteFor } from './sites.js';

const UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/**
 * A bare user-agent is not enough any more — several of these retailers gate
 * on the sec-fetch-* set that only a real navigation sends.
 */
const BROWSER_HEADERS = {
  'user-agent': UA,
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  'accept-language': 'en-US,en;q=0.9',
  'cache-control': 'no-cache',
  pragma: 'no-cache',
  'sec-ch-ua': '"Chromium";v="126", "Not;A=Brand";v="24", "Google Chrome";v="126"',
  'sec-ch-ua-mobile': '?0',
  'sec-ch-ua-platform': '"macOS"',
  'sec-fetch-dest': 'document',
  'sec-fetch-mode': 'navigate',
  'sec-fetch-site': 'none',
  'sec-fetch-user': '?1',
  'upgrade-insecure-requests': '1',
};

const TIMEOUT_MS = Number(process.env.FETCH_TIMEOUT_MS || 20_000);
const UNBLOCK_TIMEOUT_MS = Number(process.env.UNBLOCK_TIMEOUT_MS || 60_000);

export const unblockerReady = () =>
  Boolean(process.env.BRIGHTDATA_API_KEY && process.env.BRIGHTDATA_ZONE);

/**
 * Challenge pages return 200 with a body like this, so status alone lies.
 * Vendor strings are specific enough to trust anywhere in the document.
 */
const CHALLENGE_MARKERS = [
  'captcha-delivery.com',
  'px-captcha',
  '_Incapsula_Resource',
  'Request unsuccessful. Incapsula incident',
  'cf-browser-verification',
  'Checking your browser before accessing',
  'To discuss automated access to Amazon data',
];

/**
 * These are ordinary English and turn up inside the JS bundles of perfectly
 * good pages — Flipkart's 1.7MB product page contains "Access Denied"
 * somewhere and was being thrown away for it. Only trust them in the title.
 */
const CHALLENGE_TITLES = [
  'access denied',
  'robot check',
  'attention required',
  'pardon our interruption',
  'are you a human',
  'security check',
  'blocked',
];

export function looksBlocked(html) {
  if (!html || html.length < 1000) return true;
  if (CHALLENGE_MARKERS.some((marker) => html.includes(marker))) return true;

  const title = html.match(/<title[^>]*>([\s\S]{0,200}?)<\/title>/i)?.[1]?.toLowerCase() || '';
  return CHALLENGE_TITLES.some((marker) => title.includes(marker));
}

async function withTimeout(ms, run) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await run(controller.signal);
  } finally {
    clearTimeout(timer);
  }
}

async function fetchDirect(url) {
  const response = await withTimeout(TIMEOUT_MS, (signal) =>
    fetch(url, { headers: BROWSER_HEADERS, redirect: 'follow', signal }),
  );

  if (!response.ok) {
    throw Object.assign(new Error(`The retailer returned ${response.status}.`), {
      status: response.status,
      retryable: true,
    });
  }

  return { html: await response.text(), finalUrl: response.url || url, via: 'direct' };
}

/**
 * Bright Data Web Unlocker, direct API mode:
 * POST https://api.brightdata.com/request  { zone, url, format: 'raw' }
 * The response body is the target page verbatim.
 */
/** Why the cheap path did not work — worth keeping distinct in the error. */
const REASONS = {
  challenge: 'That retailer serves a bot challenge to server fetches.',
  http: 'That retailer refused the request.',
  timeout: 'That retailer did not respond in time.',
  'no-product': 'Loaded the page but could not find a product on it.',
  skipped: 'That retailer blocks server fetches.',
};

async function fetchUnblocked(url, reason = 'skipped') {
  if (!unblockerReady()) {
    const detail = REASONS[reason] || REASONS.skipped;
    throw Object.assign(
      new Error(
        reason === 'no-product'
          ? detail
          : `${detail} Set BRIGHTDATA_API_KEY to route it through the unblocker.`,
      ),
      { status: 422, reason },
    );
  }

  const response = await withTimeout(UNBLOCK_TIMEOUT_MS, (signal) =>
    fetch('https://api.brightdata.com/request', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${process.env.BRIGHTDATA_API_KEY}`,
      },
      body: JSON.stringify({
        zone: process.env.BRIGHTDATA_ZONE,
        url,
        format: 'raw',
        ...(process.env.BRIGHTDATA_COUNTRY ? { country: process.env.BRIGHTDATA_COUNTRY } : {}),
      }),
      signal,
    }),
  );

  const body = await response.text();
  if (!response.ok) {
    // Bright Data reports its own faults (bad zone, no balance) as 4xx here —
    // worth separating from the retailer's own response.
    throw Object.assign(new Error(`Unblocker failed (${response.status}): ${body.slice(0, 200)}`), {
      status: 502,
    });
  }

  return { html: body, finalUrl: url, via: 'unblocked' };
}

/**
 * Loads a page, escalating to the unblocker when the cheap path is refused.
 * `onCandidate` lets the caller accept a direct hit only if it actually parsed
 * — some sites serve a 200 shell to bots that no parser can rescue.
 */
export async function loadPage(url, { onCandidate } = {}) {
  const site = siteFor(new URL(url).hostname.replace(/^www\./, ''));
  const skipDirect = site.unblock === 'always' && unblockerReady();
  let reason = 'skipped';

  if (!skipDirect) {
    try {
      const result = await fetchDirect(url);
      if (looksBlocked(result.html)) {
        reason = 'challenge';
      } else if (!onCandidate || onCandidate(result)) {
        return result;
      } else {
        reason = 'no-product';
      }
    } catch (error) {
      reason = error.name === 'AbortError' ? 'timeout' : 'http';
      if (!error.retryable && reason !== 'timeout' && !unblockerReady()) throw error;
    }
  }

  return fetchUnblocked(url, reason);
}

/** Resolves a shortener without downloading the destination page. */
export async function resolveRedirect(url) {
  try {
    const response = await withTimeout(TIMEOUT_MS, (signal) =>
      fetch(url, { headers: BROWSER_HEADERS, redirect: 'follow', method: 'GET', signal }),
    );
    return response.url || url;
  } catch {
    return url; // Fall through and let loadPage deal with it.
  }
}

export { BROWSER_HEADERS };
