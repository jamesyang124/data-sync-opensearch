/**
 * Scenario: Stress Test
 *
 * Deliberately exceeds the target load to identify the saturation point and
 * validate graceful degradation (503 backpressure, no crashes).
 *
 * Load profile (ramping-vus — closed model):
 *   VU count is the control variable; RPS is the emergent result.
 *   Stage 1: 30s  0 → 50 VU  (≈ 500 RPS at 10 iter/VU/s)
 *   Stage 2: 60s  50 → 200 VU (≈ 1000 RPS)
 *   Stage 3: 60s  200 → 400 VU (≈ 2000 RPS)
 *   Stage 4: 20s  400 → 0 VU (cool-down)
 *
 * Thresholds are present but set abortOnFail: false so the full run
 * always completes. k6 exits non-zero on breach; the Makefile run-stress
 * target wraps the invocation with `|| exit 0` to satisfy FR-008
 * ("stress scenario MUST always exit with code 0 regardless of threshold
 * breaches").
 *
 * Breaking point detection is done by jq post-processing on the raw NDJSON
 * after k6 exits (handled in Makefile run-stress target).
 */
import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';

import { createUser, createVideo, runWorkload } from '../lib/client.js';

const BASE_URL = __ENV.BENCHMARK_BASE_URL || 'http://producer:8080';
const SETUP_USERS = parseInt(__ENV.BENCHMARK_SETUP_USERS || '200', 10);
const SETUP_VIDEOS = parseInt(__ENV.BENCHMARK_SETUP_VIDEOS || '100', 10);

const MIN_USERS = 10;
const MIN_VIDEOS = 5;

// Dedicated 503 counter for stress scenario visibility
const backpressure503 = new Counter('backpressure_503_total');

export const options = {
  scenarios: {
    stress: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { target: 50, duration: '30s' },   // ramp to baseline
        { target: 200, duration: '60s' },  // stress — ≈ 1000 RPS
        { target: 400, duration: '60s' },  // peak — ≈ 2000 RPS
        { target: 0, duration: '20s' },    // cool-down
      ],
    },
  },
  // All thresholds set abortOnFail: false — full run always completes
  // so breaking-point data is fully captured. See FR-008.
  thresholds: {
    http_req_duration: [{ threshold: 'p(95)<50', abortOnFail: false }],
    http_req_failed: [{ threshold: 'rate<0.01', abortOnFail: false }],
    'http_req_duration{endpoint:create_user}': [{ threshold: 'p(95)<50', abortOnFail: false }],
    'http_req_duration{endpoint:update_user}': [{ threshold: 'p(95)<50', abortOnFail: false }],
    'http_req_duration{endpoint:delete_user}': [{ threshold: 'p(95)<50', abortOnFail: false }],
    'http_req_duration{endpoint:create_video}': [{ threshold: 'p(95)<50', abortOnFail: false }],
  },
};

/**
 * setup() seeds the user and video pools.
 * Identical minimum guard as other scenarios.
 */
export function setup() {
  const userIds = [];
  for (let i = 0; i < SETUP_USERS; i++) {
    const { userId } = createUser(BASE_URL);
    if (userId) userIds.push(userId);
  }

  const videoIds = [];
  if (userIds.length > 0) {
    for (let i = 0; i < SETUP_VIDEOS; i++) {
      const uid = userIds[Math.floor(Math.random() * userIds.length)];
      const { videoId } = createVideo(BASE_URL, uid);
      if (videoId) videoIds.push(videoId);
    }
  }

  if (userIds.length < MIN_USERS) {
    throw new Error(
      `Pool seeding failed: seeded ${userIds.length} users (need ≥${MIN_USERS}). ` +
        `Check producer app health and database connectivity.`
    );
  }
  if (videoIds.length < MIN_VIDEOS) {
    throw new Error(
      `Pool seeding failed: seeded ${videoIds.length} videos (need ≥${MIN_VIDEOS}). ` +
        `Check that POST /api/v1/videos is reachable and user IDs are valid.`
    );
  }

  console.log(`Pool seeded: ${userIds.length} users, ${videoIds.length} videos`);
  return { userIds, videoIds };
}

/**
 * Default VU function.
 * Tracks 503 responses in a dedicated counter for saturation visibility.
 */
export default function (data) {
  const res = runWorkload(BASE_URL, data.userIds, data.videoIds);
  if (res !== undefined) {
    if (res.status === 503) {
      backpressure503.add(1);
    }
    check(res, { '2xx or expected': (r) => r.status < 400 || r.status === 404 || r.status === 409 || r.status === 503 });
  }
}

/**
 * handleSummary writes the aggregated stress report.
 * Note: handleSummary receives only aggregated totals — per-second RPS data
 * for breaking-point detection is extracted by jq from the raw NDJSON after
 * k6 exits (Makefile run-stress target).
 */
export function handleSummary(data) {
  return {
    'reports/stress-summary.json': JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}
