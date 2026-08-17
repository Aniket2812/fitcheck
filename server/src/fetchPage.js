/**
 * Fetches retailer HTML directly. This is the cheapest and most accurate path
 * when a page exposes structured product data. Bot challenges and empty app
 * shells are surfaced with a reason so extract.js can ask OpenAI web search
 * for the exact product instead.
 */

const UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/** Headers sent by a normal top-level Chrome navigation. */
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

/** Challenge pages often return 200, so status alone is not sufficient. */
const CHALLENGE_MARKERS = [
  'captcha-delivery.com',
  'px-captcha',
  '_Incapsula_Resource',
  'Request unsuccessful. Incapsula incident',
  'cf-browser-verification',
  'Checking your browser before accessing',
  'To discuss automated access to Amazon data',
];

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

const REASONS = {
  challenge: 'That retailer serves a bot challenge to server fetches.',
  http: 'That retailer refused the request.',
  timeout: 'That retailer did not respond in time.',
  'no-product': 'Loaded the page but could not find a product on it.',
};

const pageError = (reason, cause) =>
  Object.assign(new Error(REASONS[reason] || REASONS.http), {
    status: 422,
    reason,
    cause,
  });

/**
 * Loads a page directly. `onCandidate` accepts the response only when the
 * caller parsed a real product, because many retail SPAs return an empty shell.
 */
export async function loadPage(url, { onCandidate } = {}) {
  let response;
  try {
    response = await withTimeout(TIMEOUT_MS, (signal) =>
      fetch(url, { headers: BROWSER_HEADERS, redirect: 'follow', signal }),
    );
  } catch (error) {
    throw pageError(error.name === 'AbortError' ? 'timeout' : 'http', error);
  }

  if (!response.ok) throw pageError('http');

  const result = {
    html: await response.text(),
    finalUrl: response.url || url,
    via: 'direct',
  };
  if (looksBlocked(result.html)) throw pageError('challenge');
  if (onCandidate && !onCandidate(result)) throw pageError('no-product');
  return result;
}

/** Resolves a shortener without downloading the destination page twice. */
export async function resolveRedirect(url) {
  try {
    const response = await withTimeout(TIMEOUT_MS, (signal) =>
      fetch(url, { headers: BROWSER_HEADERS, redirect: 'follow', method: 'GET', signal }),
    );
    return response.url || url;
  } catch {
    return url;
  }
}

export { BROWSER_HEADERS };
