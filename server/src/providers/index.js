import * as openai from './openai.js';

// Product extraction needs a transparent asset, while YouCam Clothes is a
// person + garment virtual try-on API. They are complementary stages, not
// interchangeable providers.
export const cutoutProvider = openai;
export const describeProduct = openai.describeProduct;
