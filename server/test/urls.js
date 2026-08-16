/**
 * One sample product URL per supported retailer, used by `npm run coverage`.
 *
 * `verified: true` means the URL was confirmed to be a live product page that
 * the pipeline extracted correctly. The rest are plausible-shaped URLs that
 * have NOT been confirmed — a failure on one of those may just be a dead link,
 * so replace it with any live product page from that retailer before reading
 * anything into it. The harness marks them so the table never overstates
 * coverage.
 *
 * Product URLs rot constantly. This list exists to exercise every extraction
 * path, not to track any particular garment.
 *
 * Override the whole list with a newline-separated file:
 *   npm run coverage -- --file ./my-urls.txt
 */
export const SAMPLE_URLS = [
  // Confirmed working over a plain fetch.
  { url: 'https://www.uniqlo.com/us/en/products/E459565-000', verified: true },
  { url: 'https://www.jcrew.com/p/mens/categories/clothing/t-shirts/BX291', verified: true },
  { url: 'https://www.madewell.com/the-perfect-vintage-jean-MC504.html', verified: true },
  { url: 'https://www.nike.com/t/sportswear-club-t-shirt-ShrJfX', verified: true },
  // adidas extracted cleanly (via app-state) on the first couple of runs, then
  // started refusing this IP outright — they rate-limit rather than block
  // outright, so treat a FAIL here as "needs the unblocker", not a parser bug.
  { url: 'https://www.adidas.com/us/adicolor-classics-trefoil-tee/IA4870.html' },
  {
    url: 'https://www.levi.com/US/en_US/clothing/men/jeans/501-original-fit-mens-jeans/p/005010114',
    verified: true,
  },

  // India — confirmed working over a plain fetch.
  {
    url: 'https://www.myntra.com/lounge-tshirts/levis/levis-men-soft-pure-cotton-round-neck-half-sleeve-tshirt/12027436/buy',
    verified: true,
  },
  { url: 'https://www.bewakoof.com/p/4x4-off-road-half-sleeve-t-shirt', verified: true },
  {
    url: 'https://www.westside.com/products/wes-lounge-navy-striped-relaxed-fit-cotton-blend-trunks-pack-of-3-301076409',
    verified: true,
  },
  {
    url: 'https://www.libas.in/products/libas-art-lavender-embellished-organza-saree-1101452pa',
    verified: true,
  },
  // Not apparel, but it is the URL shape Flipkart shares and it extracts cleanly.
  { url: 'https://www.flipkart.com/vivo-t5-lite-44w-5g-wave-blue-128-gb/p/itm5420c578ec2df', verified: true },

  // India — unconfirmed. AJIO's PDP is served from `__PRELOADED_STATE__`, which
  // the extractor handles, but its category pages 403 so no live product code
  // was available to confirm it end to end.
  { url: 'https://www.ajio.com/p/441122334' },
  { url: 'https://www.nykaafashion.com/p/12345678' },
  { url: 'https://www.tatacliq.com/t-shirt/p-mp000000012345678' },
  { url: 'https://www.thesouledstore.com/product/marvel-comic-strip-boxer-shorts' },
  { url: 'https://www.biba.in/products/sample-kurta' },
  { url: 'https://www.fabindia.com/products/sample-kurta' },
  { url: 'https://www.meesho.com/sample-kurta/p/1abcde' },
  { url: 'https://www.zivame.com/sample-bra.html' },
  { url: 'https://www.amazon.in/dp/B07TXPWRQF' },

  // Unconfirmed — swap in a live product URL from each before trusting a FAIL.
  { url: 'https://www.gap.com/browse/product.do?pid=550080012' },
  { url: 'https://www.everlane.com/products/mens-premium-weight-crew-tee-black' },
  { url: 'https://www.abercrombie.com/shop/us/p/essential-tee-58323307' },
  { url: 'https://www.urbanoutfitters.com/shop/uo-standard-fit-tee' },
  { url: 'https://www.anthropologie.com/shop/the-somerset-maxi-dress' },
  { url: 'https://www.freepeople.com/shop/we-the-free-lucky-day-tank/' },
  { url: 'https://shop.mango.com/us/en/p/women/dresses/short/short-dress_87070352' },
  { url: 'https://www.cos.com/en-us/women/womenswear/dresses/product/midi-dress-black-1216115001' },
  { url: 'https://www.arket.com/en-us/women/dresses/product/1234567001' },
  { url: 'https://www.boohoo.com/mens/mens-t-shirts' },
  { url: 'https://www.prettylittlething.us/womens-dresses.html' },

  // Bot-protected hosts: expect FAIL until BRIGHTDATA_API_KEY is set, PASS after.
  { url: 'https://www.amazon.com/dp/B07TXPWRQF' },
  { url: 'https://www.zara.com/us/en/ribbed-t-shirt-p05644304.html' },
  { url: 'https://www2.hm.com/en_us/productpage.1218755001.html' },
  {
    url: 'https://www.asos.com/us/asos-design/asos-design-oversized-t-shirt-in-black/prd/203451847',
  },
  { url: 'https://us.shein.com/Solid-Drop-Shoulder-Tee-p-10556294.html' },
  { url: 'https://www.nordstrom.com/s/7455297' },
  { url: 'https://www.net-a-porter.com/en-us/shop/product/1234567' },
  { url: 'https://www.mrporter.com/en-us/mens/product/1234567' },
  { url: 'https://www.farfetch.com/shopping/men/item-12345678.aspx' },
  { url: 'https://www.ssense.com/en-us/men/product/12345678' },
  { url: 'https://www.revolve.com/dress/dp/ABCD-WD123/' },
  { url: 'https://www.aritzia.com/us/en/product/contour-longsleeve/108480.html' },
  { url: 'https://shop.lululemon.com/p/men-tops-ss/Fundamental-T-Shirt/_/prod11400060' },
  { url: 'https://www.macys.com/shop/product/style-co-womens-cotton-t-shirt' },
  { url: 'https://www.zalando.co.uk/nike-sportswear-t-shirt-ni122o0ab-q11.html' },
  { url: 'https://www.endclothing.com/us/carhartt-wip-s-s-pocket-t-shirt-i030434-89xx.html' },
];
