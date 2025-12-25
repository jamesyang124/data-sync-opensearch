# TODOs

- Message delivery strategy (at-least-once vs exactly-once trade-offs for CDC pipeline)
- Debezium message format decision (unwrap vs default envelope)
- Message consistency handling (current: optimistic lock via updated_at; consider distributed lock)
