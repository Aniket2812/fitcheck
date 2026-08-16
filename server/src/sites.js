/**
 * Per-retailer hints for the global top 30.
 *
 * The extractor is site-agnostic on purpose — this registry only carries the
 * two things a generic parser cannot infer:
 *
 *   unblock  'always' when the host refuses plain server fetches outright, so
 *            we skip straight to the unblocker instead of burning a round trip.
 *            Omitted means "try direct first, escalate only if it fails".
 *   image    A rewrite that swaps the CDN's thumbnail token for a full-size
 *            one. Cutout quality tracks input resolution closely, and og:image
 *            is frequently a 400px crop.
 *
 * A host missing from this table still works — it just gets the generic path.
 */

/** Common CDN width params, bumped to something worth cutting out. */
const WIDTH_PARAMS = ['imwidth', 'wid', 'width', 'sw', 'w', '$width$'];

function setWidth(url, width) {
  try {
    const parsed = new URL(url);
    let touched = false;
    for (const param of WIDTH_PARAMS) {
      if (parsed.searchParams.has(param)) {
        parsed.searchParams.set(param, String(width));
        touched = true;
      }
    }
    if (parsed.searchParams.has('height')) parsed.searchParams.delete('height');
    if (parsed.searchParams.has('hei')) parsed.searchParams.delete('hei');
    return touched ? parsed.toString() : url;
  } catch {
    return url;
  }
}

const SITES = {
  'amazon.com': {
    label: 'Amazon',
    unblock: 'always',
    // ".../71abc._AC_SX679_.jpg" — dropping the size token yields the original.
    image: (url) => url.replace(/\._[A-Z0-9_,]+_\.(jpg|jpeg|png|webp)/i, '.$1'),
  },
  'amazon.co.uk': { label: 'Amazon UK', unblock: 'always', alias: 'amazon.com' },
  'zara.com': {
    label: 'Zara',
    unblock: 'always',
    image: (url) => setWidth(url, 1500),
  },
  'hm.com': {
    label: 'H&M',
    unblock: 'always',
    image: (url) => setWidth(url, 1536),
  },
  'uniqlo.com': {
    label: 'Uniqlo',
    image: (url) => url.replace(/_(\d{2,3})x(\d{2,3})\./, '.'),
  },
  'asos.com': {
    label: 'ASOS',
    unblock: 'always',
    // "$n_640w$" is a Scene7 preset; the widest preset ASOS serves is 1920.
    image: (url) => url.replace(/\$n_\d+w\$/, '$n_1920w$'),
  },
  'shein.com': {
    label: 'SHEIN',
    unblock: 'always',
    image: (url) => url.replace(/_thumbnail_\d+x\d*/, '').replace(/\/thumbnail\//, '/'),
  },
  'nordstrom.com': { label: 'Nordstrom', unblock: 'always', image: (url) => setWidth(url, 1600) },
  'net-a-porter.com': { label: 'Net-A-Porter', unblock: 'always' },
  'mrporter.com': { label: 'Mr Porter', unblock: 'always', alias: 'net-a-porter.com' },
  'farfetch.com': {
    label: 'Farfetch',
    unblock: 'always',
    image: (url) => url.replace(/_(\d{3,4})\//, '_1000/'),
  },
  'ssense.com': { label: 'SSENSE', unblock: 'always' },
  'gap.com': { label: 'Gap', image: (url) => setWidth(url, 1500) },
  'oldnavy.gap.com': { label: 'Old Navy', alias: 'gap.com' },
  'bananarepublic.gap.com': { label: 'Banana Republic', alias: 'gap.com' },
  'mango.com': { label: 'Mango', image: (url) => setWidth(url, 1500) },
  'shop.mango.com': { label: 'Mango', alias: 'mango.com' },
  'cos.com': { label: 'COS', image: (url) => setWidth(url, 1536) },
  'arket.com': { label: 'Arket', image: (url) => setWidth(url, 1536) },
  'weekday.com': { label: 'Weekday', image: (url) => setWidth(url, 1536) },
  'urbanoutfitters.com': { label: 'Urban Outfitters', image: (url) => setWidth(url, 1500) },
  'everlane.com': { label: 'Everlane', image: (url) => setWidth(url, 1500) },
  'revolve.com': { label: 'Revolve', unblock: 'always' },
  'nike.com': { label: 'Nike', unblock: 'always', image: (url) => setWidth(url, 1728) },
  'adidas.com': { label: 'adidas', unblock: 'always', image: (url) => setWidth(url, 1500) },
  'levi.com': { label: "Levi's", image: (url) => setWidth(url, 1500) },
  'jcrew.com': { label: 'J.Crew', image: (url) => setWidth(url, 1500) },
  'madewell.com': { label: 'Madewell', image: (url) => setWidth(url, 1500) },
  'abercrombie.com': { label: 'Abercrombie & Fitch', image: (url) => setWidth(url, 1500) },
  'hollisterco.com': { label: 'Hollister', alias: 'abercrombie.com' },
  'aritzia.com': { label: 'Aritzia', unblock: 'always', image: (url) => setWidth(url, 1500) },
  'lululemon.com': { label: 'lululemon', unblock: 'always', image: (url) => setWidth(url, 1500) },
  'macys.com': { label: "Macy's", unblock: 'always', image: (url) => setWidth(url, 1500) },
  'zalando.com': { label: 'Zalando', unblock: 'always' },
  'zalando.co.uk': { label: 'Zalando UK', unblock: 'always', alias: 'zalando.com' },
  'endclothing.com': { label: 'END.', unblock: 'always' },
  'boohoo.com': { label: 'boohoo' },
  'prettylittlething.com': { label: 'PrettyLittleThing' },
  'anthropologie.com': { label: 'Anthropologie', image: (url) => setWidth(url, 1500) },
  'freepeople.com': { label: 'Free People', image: (url) => setWidth(url, 1500) },

  /* India ------------------------------------------------------------------ */

  'myntra.com': {
    label: 'Myntra',
    // og:image is a 200x200 crop stacked in front of the real transform:
    // /h_200,w_200,c_fill,g_auto/h_1440,q_75,w_1080/v1/... — drop the first.
    image: (url) => url.replace(/\/h_\d+,w_\d+,c_fill[^/]*\//, '/'),
  },
  'ajio.com': {
    label: 'AJIO',
    image: (url) => url.replace(/-\d{2,3}x\d{2,3}\./, '.'),
  },
  'flipkart.com': {
    label: 'Flipkart',
    // Flipkart sizes in the path: /image/128/128/... -> /image/1664/1664/...
    image: (url) => url.replace(/\/image\/\d+\/\d+\//, '/image/1664/1664/'),
  },
  'amazon.in': { label: 'Amazon India', unblock: 'always', alias: 'amazon.com' },
  'nykaafashion.com': { label: 'Nykaa Fashion', image: (url) => setWidth(url, 1500) },
  'tatacliq.com': { label: 'Tata CLiQ' },
  'bewakoof.com': {
    label: 'Bewakoof',
    image: (url) => url.replace(/\/(t_|w_)\d+[^/]*\//, '/original/'),
  },
  'thesouledstore.com': { label: 'The Souled Store' },
  'westside.com': { label: 'Westside', image: (url) => setWidth(url, 1500) },
  'snapdeal.com': { label: 'Snapdeal' },
  'zivame.com': { label: 'Zivame', unblock: 'always' },
  'biba.in': { label: 'BIBA', image: (url) => setWidth(url, 1500) },
  'fabindia.com': { label: 'Fabindia', image: (url) => setWidth(url, 1500) },
  'lifestylestores.com': { label: 'Lifestyle' },
  'meesho.com': { label: 'Meesho' },
  'urbanic.com': { label: 'Urbanic' },
  'libas.in': { label: 'Libas', image: (url) => setWidth(url, 1500) },
  'pantaloons.com': { label: 'Pantaloons' },
};

/**
 * Longest-suffix match, so "www2.hm.com" and "shop.mango.com" resolve without
 * an entry each. `alias` lets sibling storefronts share one rule set.
 */
export function siteFor(host) {
  if (!host) return {};
  let entry = SITES[host];
  if (!entry) {
    const match = Object.keys(SITES).find((key) => host === key || host.endsWith(`.${key}`));
    entry = match ? SITES[match] : null;
  }
  if (!entry) return {};
  if (entry.alias) return { ...SITES[entry.alias], ...entry, alias: undefined };
  return entry;
}

/** Generic fallbacks applied to every host, before any per-site rule. */
function genericUpgrade(url) {
  return setWidth(url, 1500)
    .replace(/\/(thumb|thumbs|thumbnail|small|medium)\//i, '/large/')
    .replace(/_(thumb|small|medium)\.(jpg|jpeg|png|webp)/i, '.$2');
}

export function upgradeImage(url, host) {
  if (!url) return url;
  const site = siteFor(host);
  const upgraded = site.image ? site.image(url) : genericUpgrade(url);
  // A rewrite that produced something unparseable is worse than the original.
  try {
    new URL(upgraded);
    return upgraded;
  } catch {
    return url;
  }
}

export const supportedSites = () =>
  Object.entries(SITES)
    .filter(([, entry]) => !entry.alias)
    .map(([host, entry]) => ({ host, label: entry.label }));
