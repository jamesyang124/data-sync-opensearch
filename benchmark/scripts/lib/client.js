import http from 'k6/http';
import { Counter } from 'k6/metrics';
import { buildUser, buildVideo } from './faker.js';

const BASE_HEADERS = { 'Content-Type': 'application/json' };

// Separate counters so 409/503 don't inflate http_req_failed rate
const conflict409 = new Counter('http_409_conflict_total');
const backpressure503 = new Counter('http_503_backpressure_total');

/**
 * Create a new User.
 * @param {string} baseUrl
 * @returns {{ response: Response, userId: string|null }}
 */
export function createUser(baseUrl) {
  const payload = JSON.stringify(buildUser());
  const res = http.post(`${baseUrl}/api/v1/users`, payload, {
    headers: BASE_HEADERS,
    tags: { endpoint: 'create_user' },
  });

  if (res.status === 409) {
    conflict409.add(1);
    return { response: res, userId: null };
  }
  if (res.status === 503) {
    backpressure503.add(1);
    return { response: res, userId: null };
  }

  let userId = null;
  if (res.status === 201 || res.status === 200) {
    try {
      userId = res.json('user_id') || res.json('id') || null;
    } catch (_) {
      // response body unparseable — userId stays null
    }
  }
  return { response: res, userId };
}

/**
 * Update an existing User.
 * @param {string} baseUrl
 * @param {string} userId
 * @returns {Response}
 */
export function updateUser(baseUrl, userId) {
  const payload = JSON.stringify(buildUser());
  const res = http.put(`${baseUrl}/api/v1/users/${userId}`, payload, {
    headers: BASE_HEADERS,
    tags: { endpoint: 'update_user' },
  });

  if (res.status === 409) conflict409.add(1);
  if (res.status === 503) backpressure503.add(1);
  return res;
}

/**
 * Delete an existing User.
 * 404 responses are expected (pool rotation; deleted users remain in pool array).
 * @param {string} baseUrl
 * @param {string} userId
 * @returns {Response}
 */
export function deleteUser(baseUrl, userId) {
  const res = http.del(`${baseUrl}/api/v1/users/${userId}`, null, {
    headers: BASE_HEADERS,
    tags: { endpoint: 'delete_user' },
  });

  if (res.status === 503) backpressure503.add(1);
  return res;
}

/**
 * Create a new Video referencing a user from the pool.
 * @param {string} baseUrl
 * @param {string} userId
 * @returns {{ response: Response, videoId: string|null }}
 */
export function createVideo(baseUrl, userId) {
  const payload = JSON.stringify(buildVideo(userId));
  const res = http.post(`${baseUrl}/api/v1/videos`, payload, {
    headers: BASE_HEADERS,
    tags: { endpoint: 'create_video' },
  });

  if (res.status === 409) {
    conflict409.add(1);
    return { response: res, videoId: null };
  }
  if (res.status === 503) {
    backpressure503.add(1);
    return { response: res, videoId: null };
  }

  let videoId = null;
  if (res.status === 201 || res.status === 200) {
    try {
      videoId = res.json('video_id') || res.json('id') || null;
    } catch (_) {
      // response body unparseable — videoId stays null
    }
  }
  return { response: res, videoId };
}

/**
 * Shared CRUD workload dispatcher.
 * Fixed weight distribution (FR-003):
 *   40% User CREATE, 20% User UPDATE, 10% User DELETE, 30% Video CREATE
 *
 * @param {string}   baseUrl
 * @param {string[]} userIds  - Pre-seeded user ID pool from setup()
 * @param {string[]} videoIds - Pre-seeded video ID pool from setup() (unused currently)
 */
export function runWorkload(baseUrl, userIds, videoIds) {
  const rand = Math.random();
  const userId = userIds[Math.floor(Math.random() * userIds.length)];

  if (rand < 0.40) {
    // 40% — Create User
    createUser(baseUrl);
  } else if (rand < 0.60) {
    // 20% — Update User
    updateUser(baseUrl, userId);
  } else if (rand < 0.70) {
    // 10% — Delete User (404 expected for already-deleted IDs)
    deleteUser(baseUrl, userId);
  } else {
    // 30% — Create Video
    createVideo(baseUrl, userId);
  }
}
