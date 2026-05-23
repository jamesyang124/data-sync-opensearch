import faker from 'k6/x/faker';

const CATEGORIES = ['education', 'music', 'gaming', 'news', 'sports'];
const SENTIMENTS = ['positive', 'neutral', 'negative'];

function pick(values) {
  return values[Math.floor(Math.random() * values.length)];
}

/**
 * Build a unique User payload matching postgres/init/01-create-schema.sql.
 * Uniqueness strategy:
 *   - channel_id: UUID prefix (globally unique)
 *   - channel_name: timestamp suffix (low collision probability at normal VU counts)
 */
export function buildUser() {
  return {
    channel_id: `channel_${faker.strings.uuid()}`,
    channel_name: `${faker.person.firstName()} ${faker.person.lastName()} ${Date.now()}`,
  };
}

/**
 * Build a Video payload.
 */
export function buildVideo() {
  return {
    video_id: `video_${faker.strings.uuid()}`,
    title: faker.word.sentence(5),
    category: pick(CATEGORIES),
  };
}

/**
 * Build a Comment payload.
 * @param {string} videoId - A video_id from the setup() pool.
 * @param {string} channelId  - A channel_id from the setup() pool.
 */
export function buildComment(videoId, channelId) {
  return {
    comment_id: `comment_${faker.strings.uuid()}`,
    video_id: videoId,
    channel_id: channelId,
    comment_text: faker.word.sentence(15),
    likes: faker.numbers.intRange(0, 5000),
    replies: faker.numbers.intRange(0, 100),
    sentiment_label: pick(SENTIMENTS),
    country_code: 'US',
  };
}
