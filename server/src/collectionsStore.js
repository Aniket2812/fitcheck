import { randomUUID } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const DATA_FILE = new URL(
  process.env.COLLECTIONS_DATA_FILE || '../data/collections.json',
  import.meta.url,
);

const DEFAULT_COLLECTIONS = [
  ['T-shirts', 'tshirt'],
  ['Shirts & Tops', 'shirt'],
  ['Jeans & Bottoms', 'jeans'],
  ['Shoes', 'shoes'],
  ['Dresses', 'dress'],
  ['Accessories', 'accessory'],
];

let loaded = false;
let state = { collections: [], items: [] };

function cleanName(value) {
  const name = String(value || '').trim();
  if (!name) throw new CollectionError('Collection name cannot be empty.');
  if (name.length > 40) throw new CollectionError('Collection names can be at most 40 characters.');
  return name;
}

function projectItem(item) {
  return {
    id: item.id,
    collectionId: item.collectionId,
    title: item.title,
    brand: item.brand,
    price: item.price,
    imageUrl: item.imageUrl,
    originalImageUrl: item.originalImageUrl,
    productImageUrls: item.productImageUrls || [],
    buyUrl: item.buyUrl,
    category: item.category,
    createdAt: item.createdAt,
  };
}

function projectCollection(collection) {
  const items = state.items
    .filter((item) => item.collectionId === collection.id)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .map(projectItem);
  return {
    id: collection.id,
    name: collection.name,
    kind: collection.kind,
    isDefault: Boolean(collection.isDefault),
    createdAt: collection.createdAt,
    items,
    itemCount: items.length,
  };
}

async function load() {
  if (loaded) return;
  try {
    const parsed = JSON.parse(await readFile(DATA_FILE, 'utf8'));
    state = {
      collections: Array.isArray(parsed.collections) ? parsed.collections : [],
      items: Array.isArray(parsed.items) ? parsed.items : [],
    };
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  loaded = true;
}

async function flush() {
  const path = fileURLToPath(DATA_FILE);
  await mkdir(dirname(path), { recursive: true });
  const temporary = `${path}.tmp`;
  await writeFile(temporary, `${JSON.stringify(state, null, 2)}\n`);
  await rename(temporary, path);
}

async function ensureDefaults(userId) {
  await load();
  if (state.collections.some((collection) => collection.userId === userId)) return;
  const now = new Date().toISOString();
  for (const [name, kind] of DEFAULT_COLLECTIONS) {
    state.collections.push({
      id: randomUUID(),
      userId,
      name,
      kind,
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    });
  }
  await flush();
}

export class CollectionError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

export async function listCollections(userId) {
  await ensureDefaults(userId);
  return state.collections
    .filter((collection) => collection.userId === userId)
    .sort((a, b) => Number(b.isDefault) - Number(a.isDefault) || a.createdAt.localeCompare(b.createdAt))
    .map(projectCollection);
}

export async function createCollection(userId, name) {
  await ensureDefaults(userId);
  const clean = cleanName(name);
  const duplicate = state.collections.some(
    (collection) => collection.userId === userId && collection.name.toLowerCase() === clean.toLowerCase(),
  );
  if (duplicate) throw new CollectionError('You already have a collection with that name.', 409);
  const now = new Date().toISOString();
  const collection = {
    id: randomUUID(),
    userId,
    name: clean,
    kind: 'custom',
    isDefault: false,
    createdAt: now,
    updatedAt: now,
  };
  state.collections.push(collection);
  await flush();
  return projectCollection(collection);
}

function ownCollection(userId, collectionId) {
  const collection = state.collections.find(
    (entry) => entry.id === collectionId && entry.userId === userId,
  );
  if (!collection) throw new CollectionError('No such collection.', 404);
  return collection;
}

export async function addCollectionItem(userId, collectionId, input) {
  await ensureDefaults(userId);
  const collection = ownCollection(userId, collectionId);
  const buyUrl = String(input?.buyUrl || input?.pageUrl || '').trim();
  if (!/^https?:\/\//i.test(buyUrl)) throw new CollectionError('A valid buying link is required.');
  const existing = state.items.find(
    (item) => item.collectionId === collection.id && item.buyUrl === buyUrl,
  );
  if (existing) return { item: projectItem(existing), created: false };
  if (state.items.filter((item) => item.collectionId === collection.id).length >= 100) {
    throw new CollectionError('A collection can keep up to 100 products.', 409);
  }
  const item = {
    id: String(input?.id || randomUUID()),
    userId,
    collectionId: collection.id,
    title: String(input?.title || 'Fashion item').slice(0, 160),
    brand: input?.brand ? String(input.brand).slice(0, 80) : null,
    price: input?.price ? String(input.price).slice(0, 40) : null,
    imageUrl: String(input?.imageUrl || input?.image || ''),
    originalImageUrl: input?.originalImageUrl || input?.originalImage || null,
    productImageUrls: (Array.isArray(input?.productImageUrls)
      ? input.productImageUrls
      : [input?.originalImageUrl || input?.originalImage || input?.imageUrl || input?.image]
    )
      .map((value) => String(value || '').trim())
      .filter(Boolean)
      .slice(0, 5),
    buyUrl,
    category: input?.category ? String(input.category) : collection.kind,
    createdAt: new Date().toISOString(),
  };
  state.items.push(item);
  collection.updatedAt = item.createdAt;
  await flush();
  return { item: projectItem(item), created: true };
}

export async function deleteCollectionItem(userId, collectionId, itemId) {
  await ensureDefaults(userId);
  ownCollection(userId, collectionId);
  const index = state.items.findIndex(
    (item) => item.id === itemId && item.collectionId === collectionId && item.userId === userId,
  );
  if (index < 0) throw new CollectionError('No such collection item.', 404);
  state.items.splice(index, 1);
  await flush();
}
