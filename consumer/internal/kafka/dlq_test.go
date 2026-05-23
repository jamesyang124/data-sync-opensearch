package kafka

import "testing"

func TestBuildDLQMessageIncludesOriginalMessageAndConsumerGroup(t *testing.T) {
	producer := &DLQProducer{consumerGroup: "test-consumer-group"}

	msg := producer.buildDLQMessage(
		"dbserver.public.users",
		3,
		42,
		[]byte("key-1"),
		[]byte(`{"bad":true}`),
		"transform failed",
		2,
	)

	if msg.OriginalTopic != "dbserver.public.users" {
		t.Fatalf("unexpected original topic: %s", msg.OriginalTopic)
	}
	if msg.OriginalPartition != 3 || msg.OriginalOffset != 42 {
		t.Fatalf("unexpected original position: partition=%d offset=%d", msg.OriginalPartition, msg.OriginalOffset)
	}
	if msg.OriginalKey != "key-1" || string(msg.OriginalValue) != `{"bad":true}` {
		t.Fatalf("original message was not preserved: key=%q value=%s", msg.OriginalKey, string(msg.OriginalValue))
	}
	if msg.ErrorContext == nil {
		t.Fatal("expected error context")
	}
	if msg.ErrorContext.ErrorMessage != "transform failed" || msg.ErrorContext.AttemptCount != 2 {
		t.Fatalf("unexpected error context: %+v", msg.ErrorContext)
	}
	if got := msg.ErrorContext.Metadata["consumer_group"]; got != "test-consumer-group" {
		t.Fatalf("unexpected consumer group metadata: %s", got)
	}
}
