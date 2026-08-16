/**
 * Coverage harness: runs the extraction half of the pipeline against one
 * product URL per retailer and prints a pass/fail table.
 *
 *   npm run coverage                 # every URL in test/urls.js
 *   npm run coverage -- --file x.txt # newline-separated URLs instead
 *   npm run coverage -- zara nike    # only rows whose host matches a filter
 *
 * Deliberately stops before the cutout: this checks that we can reach a page
 * and find the garment on it, which is the part that varies by retailer. The
 * image generation costs money and behaves the same everywhere.
 */
import { readFile } from 'node:fs/promises';

import { extractProduct } from '../src/extract.js';
import { unblockerReady } from '../src/fetchPage.js';
import { hostOf, normalizeInput } from '../src/links.js';
import { siteFor } from '../src/sites.js';
import { SAMPLE_URLS } from './urls.js';

const CONCURRENCY = Number(process.env.COVERAGE_CONCURRENCY || 4);

const argv = process.argv.slice(2);
const fileFlag = argv.indexOf('--file');
const filters = argv.filter(
  (arg, i) => !arg.startsWith('--') && !(fileFlag !== -1 && i === fileFlag + 1),
);

async function urls() {
  if (fileFlag !== -1) {
    const text = await readFile(argv[fileFlag + 1], 'utf8');
    return text
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean)
      .map((url) => ({ url, verified: true }));
  }
  return SAMPLE_URLS;
}

async function check({ url, verified }) {
  const host = hostOf(url);
  const started = Date.now();
  try {
    const product = await extractProduct(normalizeInput(url));
    return {
      host,
      verified,
      ok: true,
      ms: Date.now() - started,
      via: product.source,
      fetch: product.fetchedVia,
      title: product.title,
      price: product.price,
      // A title-less hit still passes — the LLM fallback covers it — but it is
      // worth seeing which sites lean on that.
      thin: !product.title,
    };
  } catch (error) {
    return { host, verified, ok: false, ms: Date.now() - started, error: error.message };
  }
}

/** Simple worker pool — hammering 30 retailers at once trips rate limits. */
async function run(list) {
  const results = [];
  let cursor = 0;
  await Promise.all(
    Array.from({ length: Math.min(CONCURRENCY, list.length) }, async () => {
      while (cursor < list.length) {
        results.push(await check(list[cursor++]));
        process.stdout.write('.');
      }
    }),
  );
  process.stdout.write('\n\n');
  return results;
}

const pad = (value, width) => String(value ?? '').slice(0, width).padEnd(width);

const list = (await urls()).filter(
  (entry) => !filters.length || filters.some((f) => hostOf(entry.url).includes(f)),
);

console.log(
  `Checking ${list.length} retailers — unblocker: ${unblockerReady() ? 'brightdata' : 'NOT CONFIGURED'}\n`,
);

const results = await run(list);
results.sort((a, b) => Number(b.ok) - Number(a.ok) || a.host.localeCompare(b.host));

console.log(
  `${pad('', 4)}${pad('HOST', 26)}${pad('FETCH', 10)}${pad('VIA', 12)}${pad('MS', 7)}DETAIL`,
);
console.log('-'.repeat(100));

for (const r of results) {
  const mark = r.ok ? (r.thin ? 'warn' : ' ok ') : 'FAIL';
  // An unconfirmed sample URL may simply be dead — say so rather than letting
  // the row read as a verdict on the pipeline.
  const note = r.verified ? '' : '[unverified url] ';
  const detail = r.ok ? `${r.title || '(no title)'}${r.price ? ` — ${r.price}` : ''}` : r.error;
  console.log(
    `${pad(mark, 4)}${pad(r.host, 26)}${pad(r.fetch || '-', 10)}${pad(r.via || '-', 12)}${pad(r.ms, 7)}${note}${detail}`,
  );
}

const passed = results.filter((r) => r.ok).length;
const blockedFails = results.filter((r) => !r.ok && siteFor(r.host).unblock === 'always').length;

const verifiedResults = results.filter((r) => r.verified);
const verifiedPassed = verifiedResults.filter((r) => r.ok).length;

console.log(
  `\n${passed}/${results.length} retailers extracted ` +
    `(${verifiedPassed}/${verifiedResults.length} of the confirmed-live sample URLs).`,
);
if (blockedFails && !unblockerReady()) {
  console.log(
    `${blockedFails} of the failures are bot-protected hosts. Set BRIGHTDATA_API_KEY and ` +
      'BRIGHTDATA_ZONE in server/.env and re-run.',
  );
}

// Only the confirmed-live URLs gate the exit code; the rest are informational
// until someone replaces them with a real product link.
process.exit(verifiedPassed === verifiedResults.length ? 0 : 1);
