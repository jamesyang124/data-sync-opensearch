package kafka

import (
	"testing"

	"github.com/IBM/sarama"
)

func TestNewConsumerGroupConfigAtLeastOnceAndScalingSettings(t *testing.T) {
	cfg := newConsumerGroupConfig()

	if cfg.Consumer.Offsets.AutoCommit.Enable != true {
		t.Fatal("expected offset auto-commit to be enabled after explicit message marking")
	}
	if cfg.Consumer.Offsets.Initial != sarama.OffsetNewest {
		t.Fatalf("unexpected initial offset: got %d", cfg.Consumer.Offsets.Initial)
	}
	if cfg.Consumer.Group.Rebalance.Strategy == nil {
		t.Fatal("expected consumer group rebalance strategy to be configured")
	}
	if !cfg.Consumer.Return.Errors {
		t.Fatal("expected consumer errors to be returned")
	}
}
