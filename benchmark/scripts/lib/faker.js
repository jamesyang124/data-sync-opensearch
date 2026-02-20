import faker from 'k6/x/faker';

/**
 * Build a unique User payload.
 * Uniqueness strategy:
 *   - username: timestamp suffix (low collision probability at normal VU counts)
 *   - email:    UUID prefix (guaranteed globally unique)
 */
export function buildUser() {
  return {
    username: `${faker.person.firstName()}_${faker.person.lastName()}_${Date.now()}`,
    email: `${faker.string.uuid()}@example.com`,
  };
}

/**
 * Build a Video payload referencing an existing user ID from the pool.
 * @param {string} userId - A user_id drawn from the setup() pool.
 */
export function buildVideo(userId) {
  return {
    user_id: userId,
    title: faker.lorem.sentence(5),
    description: faker.lorem.paragraph(1, 3, 10, ' '),
    duration: faker.number.intRange(60, 7200),
  };
}

/**
 * Build a Comment payload — PLACEHOLDER ONLY.
 * No HTTP requests are issued against this builder until the Comments
 * endpoint ships in the producer app. The builder exists so adding the
 * scenario is a one-file addition.
 * @param {string} videoId - A video_id from the setup() pool.
 * @param {string} userId  - A user_id from the setup() pool.
 */
export function buildComment(videoId, userId) {
  return {
    video_id: videoId,
    user_id: userId,
    comment_text: faker.lorem.sentence(15),
  };
}
