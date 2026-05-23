import http from 'k6/http';
import { Counter } from 'k6/metrics';
import { buildComment, buildUser, buildVideo } from './faker.js';

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
      userId = res.json('channel_id') || res.json('user_id') || res.json('id') || null;
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

export function updateVideo(baseUrl, videoId) {
  const payload = JSON.stringify(buildVideo());
  const res = http.put(`${baseUrl}/api/v1/videos/${videoId}`, payload, {
    headers: BASE_HEADERS,
    tags: { endpoint: 'update_video' },
  });

  if (res.status === 409) conflict409.add(1);
  if (res.status === 503) backpressure503.add(1);
  return res;
}

export function deleteVideo(baseUrl, videoId) {
  const res = http.del(`${baseUrl}/api/v1/videos/${videoId}`, null, {
    headers: BASE_HEADERS,
    tags: { endpoint: 'delete_video' },
  });

  if (res.status === 503) backpressure503.add(1);
  return res;
}

export function createComment(baseUrl, videoId, userId) {
  const payload = JSON.stringify(buildComment(videoId, userId));
  const res = http.post(`${baseUrl}/api/v1/comments`, payload, {
    headers: BASE_HEADERS,
    tags: { endpoint: 'create_comment' },
  });

  if (res.status === 409) {
    conflict409.add(1);
    return { response: res, commentId: null };
  }
  if (res.status === 503) {
    backpressure503.add(1);
    return { response: res, commentId: null };
  }

  let commentId = null;
  if (res.status === 201 || res.status === 200) {
    try {
      commentId = res.json('comment_id') || res.json('id') || null;
    } catch (_) {
      // response body unparseable — commentId stays null
    }
  }
  return { response: res, commentId };
}

export function updateComment(baseUrl, commentId, videoId, userId) {
  const payload = JSON.stringify(buildComment(videoId, userId));
  const res = http.put(`${baseUrl}/api/v1/comments/${commentId}`, payload, {
    headers: BASE_HEADERS,
    tags: { endpoint: 'update_comment' },
  });

  if (res.status === 409) conflict409.add(1);
  if (res.status === 503) backpressure503.add(1);
  return res;
}

export function deleteComment(baseUrl, commentId) {
  const res = http.del(`${baseUrl}/api/v1/comments/${commentId}`, null, {
    headers: BASE_HEADERS,
    tags: { endpoint: 'delete_comment' },
  });

  if (res.status === 503) backpressure503.add(1);
  return res;
}

/**
 * Shared CRUD workload dispatcher.
 * Fixed weight distribution:
 *   25% User CREATE, 10% User UPDATE, 5% User DELETE,
 *   20% Video CREATE, 10% Video UPDATE, 5% Video DELETE,
 *   10% Comment CREATE, 10% Comment UPDATE, 5% Comment DELETE
 *
 * @param {string}   baseUrl
 * @param {string[]} userIds  - Pre-seeded user ID pool from setup()
 * @param {string[]} videoIds - Pre-seeded video ID pool from setup()
 * @param {string[]} commentIds - Pre-seeded comment ID pool from setup()
 */
export function runWorkload(baseUrl, userIds, videoIds, commentIds = []) {
  const rand = Math.random();
  const userId = userIds[Math.floor(Math.random() * userIds.length)];
  const videoId = videoIds[Math.floor(Math.random() * videoIds.length)];
  const commentId = commentIds[Math.floor(Math.random() * commentIds.length)];

  if (rand < 0.25) {
    return createUser(baseUrl).response;
  } else if (rand < 0.35) {
    return updateUser(baseUrl, userId);
  } else if (rand < 0.40) {
    return deleteUser(baseUrl, userId);
  } else if (rand < 0.60) {
    return createVideo(baseUrl, userId).response;
  } else if (rand < 0.70) {
    return updateVideo(baseUrl, videoId);
  } else if (rand < 0.75) {
    return deleteVideo(baseUrl, videoId);
  } else if (rand < 0.85) {
    return createComment(baseUrl, videoId, userId).response;
  } else if (rand < 0.95) {
    return updateComment(baseUrl, commentId, videoId, userId);
  } else {
    return deleteComment(baseUrl, commentId);
  }
}
