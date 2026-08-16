const BASE_URL = process.env.YOUCAM_API_URL || 'https://yce-api-01.makeupar.com';
const TASK_PATH = '/s2s/v2.0/task/cloth-v3';
const FILE_PATH = '/s2s/v2.0/file/cloth-v3';
const TIMEOUT_MS = Number(process.env.YOUCAM_TIMEOUT_MS || 180_000);
const POLL_MS = Number(process.env.YOUCAM_POLL_MS || 2_000);

export const configured = Boolean(process.env.YOUCAM_API_KEY);

export class YouCamError extends Error {
  constructor(message, status = 502) {
    super(message);
    this.status = status;
  }
}

function headers(extra = {}) {
  if (!configured) {
    throw new YouCamError('YouCam is not configured on the server.', 503);
  }
  return {
    authorization: `Bearer ${process.env.YOUCAM_API_KEY}`,
    ...extra,
  };
}

async function jsonRequest(path, options = {}) {
  const response = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: headers({ 'content-type': 'application/json', ...(options.headers || {}) }),
    signal: AbortSignal.timeout(30_000),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || (payload.status && payload.status >= 400)) {
    const detail =
      payload.error?.message || payload.error || payload.message || `YouCam returned ${response.status}.`;
    throw new YouCamError(String(detail), response.status === 401 ? 502 : response.status);
  }
  return payload;
}

function normaliseContentType(type) {
  if (type === 'image/png') return 'image/png';
  if (type === 'image/jpeg' || type === 'image/jpg') return 'image/jpg';
  throw new YouCamError('YouCam try-on accepts JPG or PNG photos.', 422);
}

async function upload(buffer, contentType, fileName) {
  const type = normaliseContentType(contentType);
  const payload = await jsonRequest(FILE_PATH, {
    method: 'POST',
    body: JSON.stringify({
      files: [{ content_type: type, file_name: fileName, file_size: buffer.length }],
    }),
  });
  const file = payload.data?.files?.[0] || payload.files?.[0];
  const request = file?.requests?.[0];
  if (!file?.file_id || !request?.url) {
    throw new YouCamError('YouCam did not return an upload destination.');
  }

  const uploadResponse = await fetch(request.url, {
    method: request.method || 'PUT',
    headers: request.headers || { 'content-type': type, 'content-length': String(buffer.length) },
    body: buffer,
    signal: AbortSignal.timeout(60_000),
  });
  if (!uploadResponse.ok) {
    throw new YouCamError(`YouCam image upload failed (${uploadResponse.status}).`);
  }
  return file.file_id;
}

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

/**
 * Runs Perfect Corp's AI Clothes v3 workflow: upload a user photo, submit a
 * garment reference, poll the asynchronous task, and return the generated
 * image bytes so our own media URL remains valid after YouCam's signed URL
 * expires.
 */
export async function createTryOn({ personBuffer, personContentType, garmentUrl, category }) {
  if (!garmentUrl || !/^https?:\/\//i.test(garmentUrl)) {
    throw new YouCamError('The garment needs a public reference image.', 422);
  }
  const sourceId = await upload(personBuffer, personContentType, 'outfit-source.jpg');
  const task = await jsonRequest(TASK_PATH, {
    method: 'POST',
    body: JSON.stringify({
      src_file_id: sourceId,
      ref_file_url: garmentUrl,
      garment_category: ['upper_body', 'lower_body', 'full_body'].includes(category)
        ? category
        : 'upper_body',
    }),
  });
  const taskId = task.data?.task_id;
  if (!taskId) throw new YouCamError('YouCam did not return a task id.');

  const deadline = Date.now() + TIMEOUT_MS;
  while (Date.now() < deadline) {
    await sleep(POLL_MS);
    const status = await jsonRequest(`${TASK_PATH}/${encodeURIComponent(taskId)}`, { method: 'GET' });
    const data = status.data || status;
    if (data.task_status === 'success') {
      const url = data.results?.url;
      if (!url) throw new YouCamError('YouCam completed without an output image.');
      const image = await fetch(url, { signal: AbortSignal.timeout(30_000) });
      if (!image.ok) throw new YouCamError('Could not download the YouCam result.');
      return {
        buffer: Buffer.from(await image.arrayBuffer()),
        contentType: image.headers.get('content-type')?.split(';')[0] || 'image/jpeg',
        taskId,
      };
    }
    if (data.task_status === 'error') {
      throw new YouCamError(data.error?.message || data.error || 'YouCam could not create this look.', 422);
    }
  }
  throw new YouCamError('YouCam try-on timed out. Try a clearer, front-facing photo.', 504);
}

export const name = 'youcam-clothes-v3';
