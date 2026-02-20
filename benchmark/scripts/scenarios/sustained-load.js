/**
 * Scenario: Sustained Load
 *
 * Validates that the producer app meets its baseline throughput and latency
 * targets under steady-state production-like traffic (default: 500 RPS / 120s).
 *
 * Load profile (ramping-arrival-rate — open model):
 *   Stage 1: 10s  warm-up hold at 50 RPS
 *   Stage 2:  1s  step to BENCHMARK_TARGET_RPS
 *   Stage 3: BENCHMARK_DURATION sustained hold at target RPS
 *   Stage 4: 10s  cool-down ramp to 0 RPS
 *
 * Pass criteria: p95 < 50ms, error rate < 1%.
 */
import http from 'k6/http';
import { check } from 'k6';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';

import { thresholds } from '../lib/thresholds.js';
import { createUser, createVideo, runWorkload } from '../lib/client.js';

const BASE_URL = __ENV.BENCHMARK_BASE_URL || 'http://producer:8080';
const TARGET_RPS = parseInt(__ENV.BENCHMARK_TARGET_RPS || '500', 10);
const DURATION = __ENV.BENCHMARK_DURATION || '120s';
const PREALLOCATED_VUS = parseInt(__ENV.BENCHMARK_PREALLOCATED_VUS || '100', 10);
const MAX_VUS = parseInt(__ENV.BENCHMARK_MAX_VUS || '300', 10);
const SETUP_USERS = parseInt(__ENV.BENCHMARK_SETUP_USERS || '200', 10);
const SETUP_VIDEOS = parseInt(__ENV.BENCHMARK_SETUP_VIDEOS || '100', 10);

// Minimum pool sizes required to proceed (spec edge case — MUST guard)
const MIN_USERS = 10;
const MIN_VIDEOS = 5;

export const options = {
  scenarios: {
    sustained: {
      executor: 'ramping-arrival-rate',
      startRate: 50,
      timeUnit: '1s',
      preAllocatedVUs: PREALLOCATED_VUS,
      maxVUs: MAX_VUS,
      stages: [
        { target: 50, duration: '10s' },        // warm-up hold
        { target: TARGET_RPS, duration: '1s' },  // step to target
        { target: TARGET_RPS, duration: DURATION }, // sustained hold
        { target: 0, duration: '10s' },          // cool-down
      ],
    },
  },
  thresholds,
};

/**
 * setup() runs once before any VU starts.
 * Seeds the user and video pools used for referential integrity.
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
 * Default VU function — executes the shared CRUD workload mix on every iteration.
 * @param {{ userIds: string[], videoIds: string[] }} data - Returned by setup().
 */
export default function (data) {
  const res = runWorkload(BASE_URL, data.userIds, data.videoIds);
  // 2xx is success; 404 on DELETE and 409/503 are handled inside client.js
  if (res !== undefined) {
    check(res, { '2xx or expected': (r) => r.status < 400 || r.status === 404 || r.status === 409 || r.status === 503 });
  }
}

/**
 * handleSummary writes machine-readable and human-readable output.
 */
export function handleSummary(data) {
  return {
    'reports/sustained-summary.json': JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}
