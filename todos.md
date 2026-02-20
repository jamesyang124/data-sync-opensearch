# TODOs

- **[Next /speckit.specify]** Complete producer app (006) missing endpoints: `PUT /api/v1/videos/{id}`, `DELETE /api/v1/videos/{id}`, and full Comments CRUD (`POST/PUT/DELETE /api/v1/comments`). Currently only `POST /api/v1/videos` is implemented; benchmark suite (007) has placeholder builders ready for when these ship.
- Message delivery strategy (at-least-once vs exactly-once trade-offs for CDC pipeline)
- Debezium message format decision (unwrap vs default envelope)
- Message consistency handling (current: optimistic lock via updated_at; consider distributed lock)
