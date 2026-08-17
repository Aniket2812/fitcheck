const JPEG_SOF_MARKERS = new Set([
  0xc0,
  0xc1,
  0xc2,
  0xc3,
  0xc5,
  0xc6,
  0xc7,
  0xc9,
  0xca,
  0xcb,
  0xcd,
  0xce,
  0xcf,
]);

function pngInfo(buffer) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (buffer.length < 24 || !buffer.subarray(0, 8).equals(signature)) {
    return null;
  }
  return {
    format: 'png',
    contentType: 'image/png',
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
  };
}

function jpegInfo(buffer) {
  if (buffer.length < 4 || buffer[0] !== 0xff || buffer[1] !== 0xd8) {
    return null;
  }
  let offset = 2;
  while (offset + 8 < buffer.length) {
    if (buffer[offset] !== 0xff) {
      offset += 1;
      continue;
    }
    while (buffer[offset] === 0xff) offset += 1;
    const marker = buffer[offset];
    offset += 1;
    if (marker === 0xd8 || marker === 0xd9) continue;
    if (offset + 2 > buffer.length) break;
    const length = buffer.readUInt16BE(offset);
    if (length < 2 || offset + length > buffer.length) break;
    if (JPEG_SOF_MARKERS.has(marker) && length >= 7) {
      return {
        format: 'jpeg',
        contentType: 'image/jpeg',
        height: buffer.readUInt16BE(offset + 3),
        width: buffer.readUInt16BE(offset + 5),
      };
    }
    offset += length;
  }
  return null;
}

export function inspectImage(buffer) {
  const bytes = Buffer.from(buffer);
  return pngInfo(bytes) || jpegInfo(bytes);
}

export function validateYouCamSourceImage(buffer) {
  const info = inspectImage(buffer);
  if (!info) {
    throw Object.assign(
      new Error('Use a real JPG or PNG photo for virtual try-on.'),
      { status: 422 },
    );
  }
  const shortSide = Math.min(info.width, info.height);
  const longSide = Math.max(info.width, info.height);
  if (shortSide < 384 || longSide < 512) {
    throw Object.assign(
      new Error(
        'This photo is too small. Use a clear image of at least 512 × 384 pixels.',
      ),
      { status: 422 },
    );
  }
  if (longSide > 4096) {
    throw Object.assign(
      new Error(
        'This photo is too large. Keep its longest side under 4096 pixels.',
      ),
      { status: 422 },
    );
  }
  return info;
}
