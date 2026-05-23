import http from 'k6/http';
import { check, sleep } from 'k6';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

export const options = {
  stages: [
    { duration: '10s', target: 20 },
    { duration: '30s', target: 20 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<300'], 
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  // 1. Create User
  const channelID = `channel_${randomString(8)}`;
  
  const userPayload = JSON.stringify({
    channel_id: channelID,
    channel_name: `Channel ${randomString(8)}`,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const userRes = http.post(`${BASE_URL}/api/v1/users`, userPayload, params);
  
  const userSuccess = check(userRes, {
    'user created': (r) => r.status === 201,
  });

  if (userSuccess) {
    const videoPayload = JSON.stringify({
      video_id: `video_${randomString(8)}`,
      title: `Video ${randomString(5)}`,
      category: 'benchmark',
    });

    const videoRes = http.post(`${BASE_URL}/api/v1/videos`, videoPayload, params);
    
    check(videoRes, {
      'video created': (r) => r.status === 201,
      'has video_id': (r) => r.json('video_id') !== '',
    });
  }

  sleep(0.5);
}
