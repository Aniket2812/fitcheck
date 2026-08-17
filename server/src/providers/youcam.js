const BASE_URL = process.env.YOUCAM_API_URL || 'https://yce-api-01.makeupar.com';
const TASK_PATH = '/s2s/v2.0/task/cloth-v3';
const FILE_PATH = '/s2s/v2.0/file/cloth-v3';
const SHOES_TASK_PATH = '/s2s/v2.0/task/shoes';
const SHOES_FILE_PATH = '/s2s/v2.0/file/shoes';
const TIMEOUT_MS = Number(process.env.YOUCAM_TIMEOUT_MS || 180_000);
const POLL_MS = Number(process.env.YOUCAM_POLL_MS || 1_200);
const MAX_POLL_MS = Number(process.env.YOUCAM_MAX_POLL_MS || 3_000);
const REQUEST_TIMEOUT_MS = Number(
  process.env.YOUCAM_REQUEST_TIMEOUT_MS || 30_000,
);
const UPLOAD_TIMEOUT_MS = Number(
  process.env.YOUCAM_UPLOAD_TIMEOUT_MS || 60_000,
);

export const configured = Boolean(process.env.YOUCAM_API_KEY);

export class YouCamError extends Error {
  constructor(message, status = 502, code = 'youcam_error', retryable = false) {
    super(message);
    this.name = 'YouCamError';
    this.status = status;
    this.code = code;
    this.retryable = retryable;
  }
}

const TRANSIENT_CODES = new Set([
  'error_inference',
  'unknown_internal_error',
  'error_download_image',
  'youcam_network',
  'youcam_timeout',
]);

function providerError(error) {
  if (typeof error === 'string') return { code: error, message: null };
  if (!error || typeof error !== 'object') {
    return { code: null, message: null };
  }
  return {
    code: error.code || error.error_code || null,
    message: error.message || error.detail || null,
  };
}

function friendlyProviderMessage(code, fallback) {
  const messages = {
    error_pose:
      'We could not detect a straight, front-facing standing pose. Choose a clearer full-body photo.',
    error_invalid_src:
      'The selected photo must show one person from head to feet with the face visible.',
    error_no_face:
      'We could not see a clear face in the selected photo.',
    error_invalid_ref:
      'The outfit reference is not clear enough for a complete try-on.',
    error_apply_region_mismatch:
      'The outfit could not be aligned to this pose. Try another full-body photo.',
    error_below_min_image_size:
      'This image is too small. Use a clearer photo that is at least 512 pixels.',
    exceed_max_filesize:
      'This image is too large for YouCam. Use a photo under 10 MB.',
    error_nsfw_content_detected:
      'This image could not be processed by the provider safety checks.',
    error_editing_failed:
      'YouCam could not apply this outfit cleanly. Try another full-body photo.',
  };
  return messages[code] || fallback || 'YouCam could not create this look.';
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
  let response;
  try {
    response = await fetch(`${BASE_URL}${path}`, {
      ...options,
      headers: headers({
        'content-type': 'application/json',
        ...(options.headers || {}),
      }),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
  } catch (error) {
    if (error?.name === 'TimeoutError' || error?.name === 'AbortError') {
      throw new YouCamError(
        'YouCam did not respond in time. Please try again.',
        504,
        'youcam_timeout',
        true,
      );
    }
    throw new YouCamError(
      'Could not reach YouCam. Check the server connection and try again.',
      502,
      'youcam_network',
      true,
    );
  }

  const payload = await response.json().catch(() => ({}));
  if (!response.ok || Number(payload.status || 200) >= 400) {
    const parsed = providerError(payload.error);
    const code = parsed.code || payload.error_code || 'youcam_http';
    const fallback =
      parsed.message ||
      payload.message ||
      `YouCam returned ${response.status}.`;
    throw new YouCamError(
      friendlyProviderMessage(code, String(fallback)),
      response.status === 401 || response.status === 403
        ? 503
        : response.status,
      code,
      TRANSIENT_CODES.has(code) || response.status >= 500,
    );
  }
  return payload;
}

function normaliseContentType(type) {
  if (type === 'image/png') return 'image/png';
  if (type === 'image/jpeg' || type === 'image/jpg') return 'image/jpg';
  throw new YouCamError('YouCam try-on accepts JPG or PNG photos.', 422);
}

async function upload(buffer, contentType, fileName, filePath = FILE_PATH) {
  const type = normaliseContentType(contentType);
  const payload = await jsonRequest(filePath, {
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
    signal: AbortSignal.timeout(UPLOAD_TIMEOUT_MS),
  }).catch((error) => {
    throw new YouCamError(
      error?.name === 'TimeoutError'
        ? 'The YouCam image upload timed out. Please try again.'
        : 'The image could not be uploaded to YouCam.',
      error?.name === 'TimeoutError' ? 504 : 502,
      error?.name === 'TimeoutError' ? 'youcam_timeout' : 'youcam_network',
      true,
    );
  });
  if (!uploadResponse.ok) {
    throw new YouCamError(
      `YouCam image upload failed (${uploadResponse.status}).`,
      uploadResponse.status >= 500 ? 502 : 422,
      'youcam_upload',
      uploadResponse.status >= 500,
    );
  }
  return file.file_id;
}

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function downloadCompletedTask(taskPath, taskId) {
  const deadline = Date.now() + TIMEOUT_MS;
  let pollDelay = POLL_MS;
  while (Date.now() < deadline) {
    await sleep(pollDelay);
    const status = await jsonRequest(`${taskPath}/${encodeURIComponent(taskId)}`, { method: 'GET' });
    const data = status.data || status;
    if (data.task_status === 'success') {
      const url = data.results?.url;
      if (!url) throw new YouCamError('YouCam completed without an output image.');
      try {
        const image = await fetch(url, {
          signal: AbortSignal.timeout(30_000),
        });
        if (!image.ok) {
          throw new YouCamError(
            'Could not download the YouCam result. Please try again.',
            502,
            'error_download_image',
            true,
          );
        }
        return {
          buffer: Buffer.from(await image.arrayBuffer()),
          contentType:
            image.headers.get('content-type')?.split(';')[0] || 'image/jpeg',
          taskId,
        };
      } catch (error) {
        if (error instanceof YouCamError) throw error;
        throw new YouCamError(
          'The completed YouCam image could not be downloaded. Please try again.',
          error?.name === 'TimeoutError' ? 504 : 502,
          error?.name === 'TimeoutError'
            ? 'youcam_timeout'
            : 'error_download_image',
          true,
        );
      }
    }
    if (data.task_status === 'error') {
      const parsed = providerError(data.error);
      const code = parsed.code || data.error_code || 'error_inference';
      throw new YouCamError(
        friendlyProviderMessage(code, parsed.message),
        TRANSIENT_CODES.has(code) ? 502 : 422,
        code,
        TRANSIENT_CODES.has(code),
      );
    }
    pollDelay = Math.min(MAX_POLL_MS, Math.round(pollDelay * 1.25));
  }
  throw new YouCamError(
    'YouCam try-on timed out. Your photo is safe; please try again.',
    504,
    'youcam_timeout',
    true,
  );
}

async function submitClothesTask({
  sourceId,
  referenceId,
  referenceUrl,
  category,
}) {
  const task = await jsonRequest(TASK_PATH, {
    method: 'POST',
    body: JSON.stringify({
      src_file_id: sourceId,
      ...(referenceId
        ? { ref_file_id: referenceId }
        : { ref_file_url: referenceUrl }),
      garment_category: category,
    }),
  });
  const taskId = task.data?.task_id;
  if (!taskId) {
    throw new YouCamError(
      'YouCam did not return a task id.',
      502,
      'missing_task_id',
      true,
    );
  }
  return downloadCompletedTask(TASK_PATH, taskId);
}

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
  return submitClothesTask({
    sourceId,
    referenceUrl: garmentUrl,
    category: ['upper_body', 'lower_body', 'full_body'].includes(category)
      ? category
      : 'upper_body',
  });
}

/**
 * Transfers one already-composed, full-body outfit onto the user's photo.
 *
 * This is the reliable feed "Try on yourself" path: one Clothes v3 edit keeps
 * the source pose/background far more stable than repeatedly editing the
 * output once for every hotspot.
 */
export async function createCompleteLookTryOn({
  personBuffer,
  personContentType,
  referenceBuffer,
  referenceContentType,
}) {
  let lastError;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const [sourceId, referenceId] = await Promise.all([
        upload(
          personBuffer,
          personContentType,
          'complete-look-source.jpg',
        ),
        upload(
          referenceBuffer,
          referenceContentType,
          'complete-look-reference.jpg',
        ),
      ]);
      return await submitClothesTask({
        sourceId,
        referenceId,
        category: 'full_body',
      });
    } catch (error) {
      lastError = error;
      if (!(error instanceof YouCamError) || !error.retryable || attempt > 0) {
        throw error;
      }
    }
  }
  throw lastError;
}

export async function createShoesTryOn({ personBuffer, personContentType, garmentUrl }) {
  if (!garmentUrl || !/^https?:\/\//i.test(garmentUrl)) {
    throw new YouCamError('The shoes need a public reference image.', 422);
  }
  const sourceId = await upload(
    personBuffer,
    personContentType,
    'shoes-source.jpg',
    SHOES_FILE_PATH,
  );
  const task = await jsonRequest(SHOES_TASK_PATH, {
    method: 'POST',
    body: JSON.stringify({
      src_file_id: sourceId,
      ref_file_url: garmentUrl,
      gender: 'female',
      style: 'random',
    }),
  });
  const taskId = task.data?.task_id;
  if (!taskId) throw new YouCamError('YouCam did not return a shoes task id.');
  return downloadCompletedTask(SHOES_TASK_PATH, taskId);
}

export function createFashionTryOn(input) {
  if (input.category === 'shoes') return createShoesTryOn(input);
  if (input.category === 'accessory') {
    throw new YouCamError(
      'This accessory can be tagged and shopped, but it needs a dedicated YouCam accessory engine.',
      422,
    );
  }
  return createTryOn(input);
}

export async function createOutfitTryOn({
  personBuffer,
  personContentType,
  garments,
}) {
  const requested = Array.isArray(garments) ? garments.slice(0, 6) : [];
  if (!requested.length) throw new YouCamError('Choose at least one collection item.', 422);

  const hasFullBody = requested.some((garment) => garment.category === 'full_body');
  const supported = requested
    .filter((garment) => garment.category !== 'accessory')
    .filter(
      (garment) =>
        !hasFullBody || !['upper_body', 'lower_body'].includes(garment.category),
    )
    .sort((a, b) => {
      const order = { full_body: 0, upper_body: 1, lower_body: 2, shoes: 3 };
      return (order[a.category] ?? 4) - (order[b.category] ?? 4);
    });
  if (!supported.length) {
    throw new YouCamError(
      'These pieces need a dedicated YouCam accessory engine before they can be generated.',
      422,
    );
  }

  let currentBuffer = personBuffer;
  let currentContentType = personContentType;
  const taskIds = [];
  for (const garment of supported) {
    const result = await createFashionTryOn({
      personBuffer: currentBuffer,
      personContentType: currentContentType,
      garmentUrl: garment.garmentUrl,
      category: garment.category,
    });
    currentBuffer = result.buffer;
    currentContentType = result.contentType;
    taskIds.push(result.taskId);
  }
  return {
    buffer: currentBuffer,
    contentType: currentContentType,
    taskIds,
    appliedCount: supported.length,
    skippedCategories: requested
      .filter((garment) => !supported.includes(garment))
      .map((garment) => garment.category),
  };
}

export const name = 'youcam-clothes-v3';
