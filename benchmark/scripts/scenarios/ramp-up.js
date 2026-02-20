/**
 * Scenario: Ramp-Up
 *
 * Observes latency and error-rate behavior as load grows from zero to the
 * target rate, revealing warm-up effects and saturation onset.
 *
 * Load profile (ramping-arrival-rate — open model):
 *   Stage 1: 30s  0 → 50 RPS
 *   Stage 2: 30s  50 → 200 RPS
 *   Stage 3: 30s  200 → 500 RPS
 *   Stage 4: 60s  500 RPS hold
 *   Stage 5: 15s  500 → 0 RPS (cool-down)
 *
 * Pass criteria: p95 < 50ms during hold phase, error rate < 1% overall.
 */
import http from 'k6/http';
import { check } from 'k6';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';

import { thresholds } from '../lib/thresholds.js';
import { createUser, createVideo, runWorkload } from '../lib/client.js';

const BASE_URL = __ENV.BENCHMARK_BASE_URL || 'http://producer:8080';
const MAX_VUS = parseInt(__ENV.BENCHMARK_MAX_VUS || '300', 10);
const SETUP_USERS = parseInt(__ENV.BENCHMARK_SETUP_USERS || '200', 10);
const SETUP_VIDEOS = parseInt(__ENV.BENCHMARK_SETUP_VIDEOS || '100', 10);

const MIN_USERS = 10;
const MIN_VIDEOS = 5;

export const options = {
  scenarios: {
    ramp_up: {
      executor: 'ramping-arrival-rate',
      startRate: 0,
      timeUnit: '1s',
      preAllocatedVUs: 100,
      maxVUs: MAX_VUS,
      stages: [
        { target: 50, duration: '30s' },   // Stage 1: 0 → 50 RPS
        { target: 200, duration: '30s' },  // Stage 2: 50 → 200 RPS
        { target: 500, duration: '30s' },  // Stage 3: 200 → 500 RPS
        { target: 500, duration: '60s' },  // Stage 4: hold at 500 RPS
        { target: 0, duration: '15s' },    // Stage 5: cool-down
      ],
    },
  },
  thresholds,
};

/**
 * setup() seeds the user and video pools.
 * k6 requires setup() as a named export in each scenario file; it cannot
 * be shared via import.
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
 * Default VU function — executes the shared CRUD workload mix.
 * @param {{ userIds: string[], videoIds: string[] }} data
 */
export default function (data) {
  const res = runWorkload(BASE_URL, data.userIds, data.videoIds);
  if (res !== undefined) {
    check(res, { '2xx or expected': (r) => r.status < 400 || r.status === 404 || r.status === 409 || r.status === 503 });
  }
}

/**
 * handleSummary writes the ramp-up report files.
 * Raw NDJSON is written by the --out flag at the docker-compose / Makefile level.
 */
export function handleSummary(data) {
  return {
    'reports/ramp-summary.json': JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}
