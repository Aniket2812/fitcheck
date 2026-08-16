import { randomUUID } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, extname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
export const MEDIA_DIR = process.env.MEDIA_DIR || join(HERE, '..', 'data', 'media');
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024;

const TYPES = {
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

export class MediaError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

async function persist(bytes, contentType, prefix) {
  if (!TYPES[contentType]) throw new MediaError('Use a JPG, PNG, or WebP image.');
  if (!bytes.length || bytes.length > MAX_IMAGE_BYTES) {
    throw new MediaError('Images must be between 1 byte and 10 MB.');
  }
  await mkdir(MEDIA_DIR, { recursive: true });
  const name = `${prefix}-${randomUUID()}.${TYPES[contentType]}`;
  await writeFile(join(MEDIA_DIR, name), bytes);
  return `/media/${name}`;
}

export async function saveUploadedImage(file, prefix = 'post') {
  if (!file || typeof file.arrayBuffer !== 'function') {
    throw new MediaError('Choose an outfit photo.');
  }
  return persist(Buffer.from(await file.arrayBuffer()), file.type, prefix);
}

export async function saveImageBuffer(buffer, contentType, prefix = 'image') {
  return persist(Buffer.from(buffer), contentType, prefix);
}

export async function saveDataImage(dataUrl, prefix = 'garment') {
  const match = /^data:(image\/(?:png|jpe?g|webp));base64,([A-Za-z0-9+/=]+)$/i.exec(
    String(dataUrl || ''),
  );
  if (!match) throw new MediaError('The garment cutout is not a supported image.');
  return persist(Buffer.from(match[2], 'base64'), match[1].toLowerCase(), prefix);
}

export async function readMedia(name) {
  if (!/^[a-z0-9-]+\.(?:jpg|png|webp)$/i.test(name)) return null;
  try {
    const bytes = await readFile(join(MEDIA_DIR, name));
    const extension = extname(name).slice(1).toLowerCase();
    const contentType = extension === 'jpg' ? 'image/jpeg' : `image/${extension}`;
    return { bytes, contentType };
  } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
}
