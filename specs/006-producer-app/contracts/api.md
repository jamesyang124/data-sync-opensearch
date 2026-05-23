# API Contract: Producer Service

**Version**: 1.1.0
**Base URL**: `http://localhost:8080/api/v1`
**Schema Source**: `postgres/init/01-create-schema.sql`

## Users / Channels

### Create User

- **POST** `/users`
- **Request Body**:
  ```json
  {
    "channel_id": "channel_123",
    "channel_name": "Example Channel"
  }
  ```
- **Response**: `201 Created` with `channel_id`, `channel_name`, `created_at`, `updated_at`.

### Update User

- **PUT** `/users/{channel_id}`
- **Request Body**:
  ```json
  {
    "channel_name": "Renamed Channel"
  }
  ```
- **Response**: `200 OK`

### Delete User

- **DELETE** `/users/{channel_id}`
- **Response**: `204 No Content`

## Videos

### Create Video

- **POST** `/videos`
- **Request Body**:
  ```json
  {
    "video_id": "video_123",
    "title": "My Video",
    "category": "education"
  }
  ```
- **Response**: `201 Created`

### Update Video

- **PUT** `/videos/{video_id}`
- **Request Body**:
  ```json
  {
    "title": "Updated Video",
    "category": "news"
  }
  ```
- **Response**: `200 OK`

### Delete Video

- **DELETE** `/videos/{video_id}`
- **Response**: `204 No Content`

## Comments

### Create Comment

- **POST** `/comments`
- **Request Body**:
  ```json
  {
    "comment_id": "comment_123",
    "video_id": "video_123",
    "channel_id": "channel_123",
    "comment_text": "Great video",
    "likes": 3,
    "replies": 1,
    "sentiment_label": "positive",
    "country_code": "US"
  }
  ```
- **Response**: `201 Created`

### Update Comment

- **PUT** `/comments/{comment_id}`
- **Response**: `200 OK`

### Delete Comment

- **DELETE** `/comments/{comment_id}`
- **Response**: `204 No Content`

## Health And Metrics

- **GET** `/health`: returns status and database connectivity.
- **GET** `/metrics`: returns JSON runtime and database pool metrics.

## Error Mapping

- Invalid JSON: `400 Bad Request`
- Duplicate primary key: `409 Conflict`
- Missing foreign key for comments: `409 Conflict`
- Missing entity on update/delete: `404 Not Found`
