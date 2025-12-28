# Data Model: Test Data Service

**Status**: Phase 1 Design
**Source**: Postgres Schema (Feature 001)

## Entities

The application exposes the following entities via the API.

### 1. User
Represents a platform user.

| Field | Type | Constraint |
|-------|------|------------|
| `user_id` | UUID | PK |
| `username` | VARCHAR(50) | Unique |
| `email` | VARCHAR(255) | Unique |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

### 2. Video
Represents a video uploaded by a user.

| Field | Type | Constraint |
|-------|------|------------|
| `video_id` | UUID | PK |
| `user_id` | UUID | FK -> Users |
| `title` | VARCHAR(255) | |
| `description` | TEXT | |
| `duration` | INT | |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

### 3. Comment
Represents a comment on a video.

| Field | Type | Constraint |
|-------|------|------------|
| `comment_id` | UUID | PK |
| `video_id` | UUID | FK -> Videos |
| `user_id` | UUID | FK -> Users |
| `comment_text` | TEXT | |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

## Go Structs (Draft)

```go
package models

import (
	"time"
	"github.com/google/uuid"
)

type User struct {
	ID        uuid.UUID `db:"user_id" json:"user_id"`
	Username  string    `db:"username" json:"username"`
	Email     string    `db:"email" json:"email"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

type Video struct {
	ID          uuid.UUID `db:"video_id" json:"video_id"`
	UserID      uuid.UUID `db:"user_id" json:"user_id"`
	Title       string    `db:"title" json:"title"`
	Description string    `db:"description" json:"description"`
	Duration    int       `db:"duration" json:"duration"`
	CreatedAt   time.Time `db:"created_at" json:"created_at"`
	UpdatedAt   time.Time `db:"updated_at" json:"updated_at"`
}

type Comment struct {
	ID          uuid.UUID `db:"comment_id" json:"comment_id"`
	VideoID     uuid.UUID `db:"video_id" json:"video_id"`
	UserID      uuid.UUID `db:"user_id" json:"user_id"`
	Text        string    `db:"comment_text" json:"comment_text"`
	CreatedAt   time.Time `db:"created_at" json:"created_at"`
	UpdatedAt   time.Time `db:"updated_at" json:"updated_at"`
}
```

## Relationships & Integrity

- **Foreign Keys**: The API will return `409 Conflict` or `400 Bad Request` if a foreign key constraint is violated (e.g., trying to create a Video for a non-existent User).