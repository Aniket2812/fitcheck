import { readFile, writeFile } from 'node:fs/promises';

const feedUrl = new URL('../seed/feed.json', import.meta.url);
const visualUrl = new URL('../seed/visual-matches.json', import.meta.url);
const feed = JSON.parse(await readFile(feedUrl, 'utf8'));
const previousVisual = JSON.parse(await readFile(visualUrl, 'utf8'));

const products = new Map();
for (const garment of feed.posts.flatMap((post) => post.garments)) {
  if (!products.has(garment.imageUrl)) {
    products.set(garment.imageUrl, { ...garment });
  }
}

const updateProduct = (imageName, title, brand, price, buyUrl) => {
  const product = products.get(`/media/${imageName}.jpg`);
  if (!product) throw new Error(`Unknown demo product: ${imageName}`);
  Object.assign(product, { title, brand, price, buyUrl });
};

updateProduct('maya-white-fitted-tee', 'White slim-fit crew-neck T-shirt', 'AJIO', '₹499', 'https://www.ajio.com/ajio-slim-fit-crew-neck-t-shirt-with-contrast-neckline/p/460516501_white');
updateProduct('maya-black-trousers', 'Black high-waisted wide-leg tailored trousers', 'H&M', '₹1,399', 'https://www.myntra.com/bottomwear/h%26m/h%26m-women-black-high-waisted-tailored-trousers/19410206/buy');
updateProduct('zoya-black-sandals', 'Black open-toe block heels', 'NTFC', '₹924', 'https://www.myntra.com/heels/ntfc/ntfc-women-black-open-toe-block-heels/35406641/buy');
updateProduct('kabir-black-knit', 'Black crew-neck knit pullover', 'SNITCH', '₹999', 'https://www.ajio.com/snitch-men-crew-neck-pullover/p/700634602_black');
updateProduct('kabir-black-trousers', 'Men black slim-fit tailored trousers', 'BASICS', '₹1,259', 'https://www.myntra.com/trousers/basics/basics-men-black-trousers/17957736/buy');
updateProduct('kabir-brown-boots', 'Men dark-brown leather Chelsea boots', 'Roadster', '₹1,267', 'https://www.myntra.com/shoes/roadster/roadster-men-brown-leather-chelsea-boots/36648648/buy');
updateProduct('rehan-white-trousers', 'White relaxed-fit linen trousers', 'Kingdom of White', '₹1,199', 'https://www.myntra.com/trousers/kingdom20of20white/kingdom-of-white-men-relaxed-fit-linen-trousers/31889229/buy');
updateProduct('rehan-sunglasses', 'Brown square UV-protected sunglasses', 'Fastrack', '₹855', 'https://www.myntra.com/sunglasses/fastrack/fastrack-men-square-sunglasses-with-uv-protected-lens-p357br3v/30439204/buy');
updateProduct('rehan-brown-loafers', 'Brown genuine-leather penny loafers', 'Hush Puppies', '₹2,799', 'https://www.ajio.com/hush-puppies-men-genuine-leather-penny-loafers/p/467025726007');
updateProduct('zoya-grey-tee', 'Grey solid round-neck T-shirt', 'NEXT', '₹449', 'https://www.myntra.com/tshirts/next/next-grey-solid-round-neck-t-shirt/10908646/buy');
updateProduct('zoya-black-skirt', 'Black fluid A-line midi skirt', 'Bitterlime', '₹799', 'https://www.myntra.com/skirts/bitterlime/bitterlime-black-midi-a-line-skirt/8224951/buy');
updateProduct('zoya-black-boots', 'Women black round-toe block-heel ankle boots', 'Inc 5', '₹5,990', 'https://www.myntra.com/boots/inc5/inc-5-women-block-heeled-round-toe-ankle-boots/35266328/buy');
updateProduct('maya-black-tank', 'Black fitted tank top', 'CAVA', '₹599', 'https://www.myntra.com/tops/cava/cava-black-tank-us-later-top/27045222/buy');
updateProduct('maya-black-shoulder-bag', 'Cindy black curved shoulder bag', 'MIRAGGIO', '₹2,549', 'https://www.myntra.com/handbags/miraggio/miraggio-black-half-moon-shoulder-bag/20894552/buy');
updateProduct('arjun-cream-polo', 'Cream self-design textured polo T-shirt', 'BE POSITIVE', '₹854', 'https://www.myntra.com/tshirts/bepositive/be-positive-cream-self-design-polo-collar-t-shirt/37028708/buy');
updateProduct('arjun-black-trousers', 'Men black relaxed-fit cotton trousers', 'SHOWOFFFF', '₹1,019', 'https://www.myntra.com/trousers/showoff/showoff-men-black-relaxed-fit-cotton-regular-trousers/36620272/buy');
updateProduct('arjun-black-sunglasses', 'Black wayfarer UV-protected sunglasses', 'Voyage', '₹809', 'https://www.myntra.com/eyewear/voyage/voyage-unisex-black-lens-%26-black-wayfarer-sunglasses-with-uv-protected-lens/19037770/buy');
updateProduct('zoya-cream-trousers', 'Beige tailored straight-fit trousers', 'FABLE STREET', '₹1,856', 'https://www.myntra.com/trousers/fablestreet/fablestreet-women-tailored-beige-straight-fit-trousers/36532000/buy');
updateProduct('zoya-cream-shoulder-bag', 'Bryna cream curved hobo bag', 'CHARLES & KEITH', '₹7,499', 'https://www.myntra.com/handbags/charles26keith/charles--keith-bryna-curved-hobo-bag/40060269/buy');
updateProduct('maya-black-top', 'Black sleeveless scoop-neck fitted top', 'StyleCast', '₹1,199', 'https://www.myntra.com/tops/stylecast/stylecast-women-scoop-neck-fitted-crop-top/31685837/buy');
updateProduct('maya-black-jeans', 'Washed-black straight-fit high-rise jeans', 'SASSAFRAS Curve', '₹1,149', 'https://www.myntra.com/jeans/sassafrascurve/sassafras-curve-women-black-comfort-straight-fit-high-rise-clean-look-acid-wash-jeans/24203430/buy');
updateProduct('arjun-brown-loafers', 'Coffee-brown formal penny loafers', 'HERE&NOW', '₹648', 'https://www.myntra.com/formal-shoes/here%26now/herenow-men-coffee-brown-formal-penny-loafers-/26242990/buy');
updateProduct('maya-cream-trousers', 'Cream formal high-rise wide-leg trousers', 'StyleCast X Kotty', '₹540', 'https://www.myntra.com/trousers/stylecastxkotty/cream-formal-high-rise-wide-leg-trousers/40555467/buy');
updateProduct('zoya-tan-sandals', 'Tan open-toe comfort block heels', 'Metro', '₹1,293', 'https://www.myntra.com/heels/metro/metro-open-toe-block-heels/23060486/buy');
updateProduct('zoya-gold-earrings', 'Gold-plated filigree teardrop drop earrings', 'justpeachy', '₹1,405', 'https://www.myntra.com/earrings/justpeachy/justpeachy-gold-plated-filigree-teardrop-shaped-drop-earrings/13497228/buy');
updateProduct('zoya-tan-bag', 'Mini Haylen tan shoulder bag', 'Charles & Keith', '₹9,499', 'https://www.charleskeith.in/in/CK2-20151647_DS.TAN_S-IN.html');

const retailerSku = (value) => {
  const url = new URL(value);
  const path = url.pathname;
  if (url.hostname.includes('amazon.')) return path.match(/\/dp\/([A-Z0-9]{10})/i)?.[1]?.toUpperCase();
  if (url.hostname.includes('myntra.com')) return path.match(/\/(\d+)\/buy\/?$/)?.[1];
  if (url.hostname.includes('ajio.com')) return path.match(/\/p\/([^/]+)\/?$/)?.[1];
  if (url.hostname.includes('hm.com')) return path.match(/productpage\.(\d+)\.html/)?.[1];
  if (url.hostname.includes('puma.com')) return [path.match(/\/pd\/[^/]+\/(\d+)/)?.[1], url.searchParams.get('swatch')].filter(Boolean).join('-');
  if (url.hostname.includes('uniqlo.com')) return path.match(/\/products\/(E\d+-\d+)/)?.[1];
  if (url.hostname.includes('levi.in')) return path.split('/').filter(Boolean).at(-1);
  if (url.hostname.includes('charleskeith.')) return path.match(/\/(CK.+)\.html/i)?.[1];
  if (url.hostname.includes('mango.com')) return path.match(/(?:_|\/)(\d{8})(?:\/|$)/)?.[1];
  if (url.hostname.includes('adidas.')) return path.match(/\/([A-Z0-9]+)\.html/i)?.[1];
  return null;
};

for (const [imageUrl, product] of products) {
  product.catalogKey = imageUrl.split('/').at(-1).replace(/\.jpg$/, '');
  product.retailerSku = retailerSku(product.buyUrl);
  product.productImageUrls = [imageUrl];
  if (!product.retailerSku) throw new Error(`Cannot extract SKU: ${product.buyUrl}`);
}

const remixProducts = {
  'demo-post-monochrome-remix': [['white-fitted-tee', 'maya-white-fitted-tee', .5, .3], ['black-wide-trousers', 'maya-black-trousers', .52, .58], ['red-sneakers', 'maya-red-sneakers', .5, .91]],
  'demo-post-clean-denim-remix': [['soft-white-tee', 'arjun-white-tee', .5, .3], ['blue-straight-jeans', 'arjun-blue-jeans', .5, .59], ['white-sneakers', 'arjun-white-sneakers', .5, .91]],
  'demo-post-after-dark-remix': [['black-satin-dress', 'zoya-black-dress', .47, .47], ['black-block-heels', 'zoya-black-sandals', .5, .91], ['tan-shoulder-bag', 'zoya-tan-bag', .67, .34]],
  'demo-post-tonal-coffee-remix': [['black-crew-pullover', 'kabir-black-knit', .5, .31], ['men-black-trousers', 'kabir-black-trousers', .5, .6], ['brown-chelsea-boots', 'kabir-brown-boots', .5, .9]],
  'demo-post-resort-neutral-remix': [['sand-linen-shirt', 'rehan-sand-shirt', .5, .31], ['white-linen-trousers', 'rehan-white-trousers', .5, .6], ['square-sunglasses', 'rehan-sunglasses', .5, .17], ['brown-loafers', 'rehan-brown-loafers', .5, .91]],
  'demo-post-indigo-skirt-remix': [['indigo-denim-jacket', 'zoya-indigo-jacket', .5, .31], ['grey-tee', 'zoya-grey-tee', .5, .31], ['black-midi-skirt', 'zoya-black-skirt', .5, .6], ['black-ankle-boots', 'zoya-black-boots', .5, .91]],
  'demo-post-utility-night-remix': [['black-tank', 'maya-black-tank', .5, .3], ['olive-cargo-trousers', 'maya-olive-cargo-trousers', .5, .6], ['black-shoulder-bag', 'maya-black-shoulder-bag', .34, .34], ['black-flat-sandals', 'maya-black-sandals', .5, .91]],
  'demo-post-polo-after-hours-remix': [['cream-knit-polo', 'arjun-cream-polo', .5, .31], ['relaxed-black-trousers', 'arjun-black-trousers', .5, .6], ['black-gum-sneakers', 'arjun-black-sneakers', .5, .91]],
  'demo-post-blush-denim-remix': [['pink-cardigan', 'zoya-pink-cardigan', .5, .31], ['light-blue-wide-jeans', 'zoya-light-blue-jeans', .5, .6], ['pink-shoulder-bag', 'zoya-pink-shoulder-bag', .34, .32], ['pink-sneakers', 'zoya-pink-sneakers', .5, .91]],
  'demo-post-red-cream-remix': [['red-cardigan', 'maya-red-cardigan-product', .5, .31], ['cream-wide-trousers', 'maya-cream-trousers', .5, .6], ['cream-loafers', 'maya-cream-loafers', .5, .91], ['black-curved-bag', 'maya-black-shoulder-bag', .34, .34]],
};

const remixImageNames = {
  'demo-post-monochrome-remix': 'monochrome',
  'demo-post-clean-denim-remix': 'clean-denim',
  'demo-post-after-dark-remix': 'after-dark',
  'demo-post-tonal-coffee-remix': 'tonal-coffee',
  'demo-post-resort-neutral-remix': 'resort-neutral',
  'demo-post-indigo-skirt-remix': 'indigo-skirt',
  'demo-post-utility-night-remix': 'utility-night',
  'demo-post-polo-after-hours-remix': 'polo-after-hours',
  'demo-post-blush-denim-remix': 'blush-denim',
  'demo-post-red-cream-remix': 'red-cream',
};

for (const post of feed.posts) {
  const remix = remixProducts[post.id];
  if (remix) {
    post.imageUrl = `/media/studio-remix-${remixImageNames[post.id]}.jpg`;
    post.garments = remix.map(([id, key, x, y]) => ({
      ...products.get(`/media/${key}.jpg`),
      id: `demo-garment-remix-${id}`,
      x,
      y,
    }));
  } else {
    post.garments = post.garments.map((garment) => ({
      ...products.get(garment.imageUrl),
      id: garment.id,
      x: garment.x,
      y: garment.y,
    }));
  }
}

feed.version = 10;
await writeFile(feedUrl, `${JSON.stringify(feed, null, 2)}\n`);

const visualByProduct = new Map();
for (const match of previousVisual.matches) {
  if (!visualByProduct.has(match.productImage)) visualByProduct.set(match.productImage, match);
}
const visual = {
  version: 4,
  matches: feed.posts.flatMap((post) => post.garments.map((garment) => {
    const previous = visualByProduct.get(garment.imageUrl);
    if (!previous) throw new Error(`Missing visual description: ${garment.imageUrl}`);
    return {
      postId: post.id,
      garmentId: garment.id,
      postImage: post.imageUrl,
      productImage: garment.imageUrl,
      colour: previous.colour,
      product: previous.product,
      catalogKey: garment.catalogKey,
      retailerSku: garment.retailerSku,
      buyUrl: garment.buyUrl,
    };
  })),
};
await writeFile(visualUrl, `${JSON.stringify(visual, null, 2)}\n`);

console.log(JSON.stringify({ version: feed.version, posts: feed.posts.length, garments: visual.matches.length, products: products.size }));
