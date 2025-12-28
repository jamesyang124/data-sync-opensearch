import http from 'k6/http';
import { check, sleep } from 'k6';
import { randomString, randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

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
  const username = `user_${randomString(8)}`;
  const email = `${username}@example.com`;
  
  const userPayload = JSON.stringify({
    username: username,
    email: email,
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
    const userId = userRes.json('user_id');

    // 2. Create Video for that User
    const videoPayload = JSON.stringify({
      user_id: userId,
      title: `Video ${randomString(5)}`,
      description: `Description for video ${randomString(10)}`,
      duration: randomIntBetween(60, 3600),
    });

    const videoRes = http.post(`${BASE_URL}/api/v1/videos`, videoPayload, params);
    
    check(videoRes, {
      'video created': (r) => r.status === 201,
      'has video_id': (r) => r.json('video_id') !== '',
    });
  }

  sleep(0.5);
}
