# API Contract: Producer Service

**Version**: 1.0.0
**Base URL**: `http://localhost:8080/api/v1`

## Endpoints

### 1. Create User
Creates a single user record.

- **POST** `/users`
- **Request Body**:
  ```json
  {
    "username": "john_doe",
    "email": "john@example.com"
  }
  ```
- **Response (201 Created)**:
  ```json
  {
    "user_id": "uuid-string",
    "username": "john_doe",
    "created_at": "timestamp"
  }
  ```

### 2. Update User
Updates an existing user.

- **PUT** `/users/{user_id}`
- **Request Body**:
  ```json
  {
    "username": "new_username",
    "email": "new@example.com"
  }
  ```
- **Response (200 OK)**:
  ```json
  {
    "user_id": "uuid-string",
    "username": "new_username",
    "updated_at": "timestamp"
  }
  ```

### 3. Delete User
Deletes a user.

- **DELETE** `/users/{user_id}`
- **Response (204 No Content)**

### 4. Create Video
Creates a video record.

- **POST** `/videos`
- **Request Body**:
  ```json
  {
    "user_id": "uuid-string",
    "title": "My Video",
    "description": "Video description",
    "duration": 120
  }
  ```
- **Response (201 Created)**:
  ```json
  {
    "video_id": "uuid-string",
    "title": "My Video"
  }
  ```

### 3. Health Check
Standard health check.

- **GET** `/health`
- **Response (200 OK)**:
  ```json
  {
    "status": "up",
    "db_connection": true
  }
  ```

### 4. Metrics
Application metrics.

- **GET** `/metrics`
- **Response**: JSON object containing request counts, DB pool stats, and uptime.
