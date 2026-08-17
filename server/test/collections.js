import assert from 'node:assert/strict';
import { rm } from 'node:fs/promises';

const dataFile = `/tmp/youcam2-collections-${process.pid}.json`;
process.env.COLLECTIONS_DATA_FILE = dataFile;

const {
  addCollectionItem,
  createCollection,
  deleteCollectionItem,
  listCollections,
} = await import('../src/collectionsStore.js');

try {
  const defaults = await listCollections('user-1');
  assert.equal(defaults.length, 6);
  assert.deepEqual(
    defaults.map((collection) => collection.name),
    ['T-shirts', 'Shirts & Tops', 'Jeans & Bottoms', 'Shoes', 'Dresses', 'Accessories'],
  );

  const custom = await createCollection('user-1', 'Hackathon finals');
  assert.equal(custom.isDefault, false);

  const first = await addCollectionItem('user-1', defaults[0].id, {
    id: 'tee-1',
    title: 'Graphic tee',
    imageUrl: 'https://example.com/tee.png',
    originalImageUrl: 'https://example.com/tee.jpg',
    productImageUrls: [
      'https://example.com/tee-front.jpg',
      'https://example.com/tee-back.jpg',
      'https://example.com/tee-detail.jpg',
      'https://example.com/tee-side.jpg',
    ],
    buyUrl: 'https://example.com/products/tee',
    category: 'upper_body',
  });
  assert.equal(first.created, true);

  const duplicate = await addCollectionItem('user-1', defaults[0].id, {
    title: 'Same tee',
    buyUrl: 'https://example.com/products/tee',
  });
  assert.equal(duplicate.created, false);

  const populated = await listCollections('user-1');
  assert.equal(populated[0].itemCount, 1);
  assert.equal(populated[0].items[0].title, 'Graphic tee');
  assert.equal(populated[0].items[0].productImageUrls.length, 4);

  await deleteCollectionItem('user-1', defaults[0].id, first.item.id);
  assert.equal((await listCollections('user-1'))[0].itemCount, 0);
  console.log('collections: defaults, custom, add, de-duplicate, delete — ok');
} finally {
  await rm(dataFile, { force: true });
}
