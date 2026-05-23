/**
 * Benchmark entry point.
 *
 * Reads __ENV.BENCHMARK_SCENARIO and routes to the matching scenario module.
 *
 * IMPORTANT: Static imports are used intentionally — the Goja ES6 runtime
 * used by k6 does not support dynamic import() expressions. All scenario
 * modules must be imported at the top of this file.
 */
import http, { expectedStatuses, setResponseCallback } from 'k6/http';
import { sleep } from 'k6';

import * as sustained from './scenarios/sustained-load.js';
import * as rampUp from './scenarios/ramp-up.js';
import * as stress from './scenarios/stress.js';

const BASE_URL = __ENV.BENCHMARK_BASE_URL || 'http://producer:8080';
const SCENARIO = __ENV.BENCHMARK_SCENARIO || 'sustained';

setResponseCallback(expectedStatuses({ min: 200, max: 399 }, 404, 409, 503));

// ---------------------------------------------------------------------------
// Pre-flight health check
// Runs before setup() in every scenario. Aborts immediately if the producer
// app is not healthy so the benchmark doesn't run a meaningless test.
// ---------------------------------------------------------------------------
function checkHealth() {
  const res = http.get(`${BASE_URL}/health`);
  if (res.status !== 200) {
    throw new Error(
      `Producer app not healthy — aborting benchmark. ` +
        `GET ${BASE_URL}/health returned HTTP ${res.status}.`
    );
  }
}

// ---------------------------------------------------------------------------
// Route to scenario
// ---------------------------------------------------------------------------
let activeScenario;

switch (SCENARIO) {
  case 'sustained':
    activeScenario = sustained;
    break;
  case 'ramp-up':
    activeScenario = rampUp;
    break;
  case 'stress':
    activeScenario = stress;
    break;
  default:
    throw new Error(
      `Unknown BENCHMARK_SCENARIO: "${SCENARIO}". ` +
        `Valid values: sustained, ramp-up, stress.`
    );
}

// ---------------------------------------------------------------------------
// k6 lifecycle exports — delegate to the active scenario module
// ---------------------------------------------------------------------------

// options must be a named export; k6 reads it at startup
export const options = activeScenario.options;

export function setup() {
  checkHealth();
  return activeScenario.setup ? activeScenario.setup() : {};
}

export default function (data) {
  activeScenario.default(data);
}

export function handleSummary(data) {
  return activeScenario.handleSummary ? activeScenario.handleSummary(data) : {};
}
