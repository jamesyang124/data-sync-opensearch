/**
 * Shared threshold definitions for all benchmark scenarios.
 *
 * Global thresholds apply to every scenario.
 * Per-endpoint sub-metric thresholds use the `endpoint` tag set on every
 * HTTP request in client.js per the tagging contract.
 *
 * Scenarios that should not gate CI on threshold breaches (e.g. stress)
 * must override these with `abortOnFail: false` on each entry.
 */
export const thresholds = {
  // Global latency and error rate
  http_req_duration: ['p(95)<50'],
  http_req_failed: ['rate<0.01'],

  // Per-endpoint latency (tagged in client.js)
  'http_req_duration{endpoint:create_user}': ['p(95)<50'],
  'http_req_duration{endpoint:update_user}': ['p(95)<50'],
  'http_req_duration{endpoint:delete_user}': ['p(95)<50'],
  'http_req_duration{endpoint:create_video}': ['p(95)<50'],
  'http_req_duration{endpoint:update_video}': ['p(95)<50'],
  'http_req_duration{endpoint:delete_video}': ['p(95)<50'],
  'http_req_duration{endpoint:create_comment}': ['p(95)<50'],
  'http_req_duration{endpoint:update_comment}': ['p(95)<50'],
  'http_req_duration{endpoint:delete_comment}': ['p(95)<50'],
};
