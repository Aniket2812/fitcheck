import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';

const uploads = [];
let taskPayload;
let fileNumber = 0;
const resultImage = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
  'base64',
);

const server = createServer(async (request, response) => {
  const url = new URL(request.url, 'http://127.0.0.1');
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  const bytes = Buffer.concat(chunks);

  if (request.method === 'POST' && url.pathname === '/s2s/v2.0/file/cloth-v3') {
    fileNumber += 1;
    const fileId = `file-${fileNumber}`;
    response.setHeader('content-type', 'application/json');
    response.end(
      JSON.stringify({
        status: 200,
        data: {
          files: [
            {
              file_id: fileId,
              requests: [
                {
                  method: 'PUT',
                  url: `http://127.0.0.1:${server.address().port}/upload/${fileId}`,
                  headers: { 'content-type': 'image/jpg' },
                },
              ],
            },
          ],
        },
      }),
    );
    return;
  }

  if (request.method === 'PUT' && url.pathname.startsWith('/upload/')) {
    uploads.push({ path: url.pathname, bytes });
    response.statusCode = 200;
    response.end();
    return;
  }

  if (request.method === 'POST' && url.pathname === '/s2s/v2.0/task/cloth-v3') {
    taskPayload = JSON.parse(bytes.toString('utf8'));
    response.setHeader('content-type', 'application/json');
    response.end(JSON.stringify({ status: 200, data: { task_id: 'task-1' } }));
    return;
  }

  if (
    request.method === 'GET' &&
    url.pathname === '/s2s/v2.0/task/cloth-v3/task-1'
  ) {
    response.setHeader('content-type', 'application/json');
    response.end(
      JSON.stringify({
        status: 200,
        data: {
          task_status: 'success',
          results: {
            url: `http://127.0.0.1:${server.address().port}/result.png`,
          },
        },
      }),
    );
    return;
  }

  if (request.method === 'GET' && url.pathname === '/result.png') {
    response.setHeader('content-type', 'image/png');
    response.end(resultImage);
    return;
  }

  response.statusCode = 404;
  response.end();
});

await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
process.env.YOUCAM_API_KEY = 'test-key';
process.env.YOUCAM_API_URL = `http://127.0.0.1:${server.address().port}`;
process.env.YOUCAM_POLL_MS = '1';
process.env.YOUCAM_MAX_POLL_MS = '1';

try {
  const { createCompleteLookTryOn } = await import(
    `../src/providers/youcam.js?complete-look-test=${Date.now()}`
  );
  const photo = await readFile(
    new URL('../seed/media/studio-arjun-denim-day.jpg', import.meta.url),
  );
  const result = await createCompleteLookTryOn({
    personBuffer: photo,
    personContentType: 'image/jpeg',
    referenceBuffer: photo,
    referenceContentType: 'image/jpeg',
  });

  assert.equal(uploads.length, 2);
  assert.ok(uploads.every((upload) => upload.bytes.equals(photo)));
  assert.deepEqual(taskPayload, {
    src_file_id: 'file-1',
    ref_file_id: 'file-2',
    garment_category: 'full_body',
  });
  assert.equal(result.taskId, 'task-1');
  assert.equal(result.contentType, 'image/png');
  assert.ok(result.buffer.equals(resultImage));
  console.log('YouCam complete look: two uploads, one full-body task — ok');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
