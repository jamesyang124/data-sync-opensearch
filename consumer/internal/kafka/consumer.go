package kafka

import (
	"context"

	"github.com/IBM/sarama"
	"go.uber.org/zap"
)

// Consumer wraps Sarama consumer group
type Consumer struct {
	client  sarama.ConsumerGroup
	topics  []string
	handler sarama.ConsumerGroupHandler
	logger  *zap.Logger
}

// NewConsumer creates a new Kafka consumer
func NewConsumer(brokers []string, group string, topics []string, handler sarama.ConsumerGroupHandler, logger *zap.Logger) (*Consumer, error) {
	config := newConsumerGroupConfig()

	client, err := sarama.NewConsumerGroup(brokers, group, config)
	if err != nil {
		return nil, err
	}

	return &Consumer{
		client:  client,
		topics:  topics,
		handler: handler,
		logger:  logger,
	}, nil
}

func newConsumerGroupConfig() *sarama.Config {
	config := sarama.NewConfig()
	config.Version = sarama.V3_0_0_0
	config.Consumer.Group.Rebalance.Strategy = sarama.NewBalanceStrategyRoundRobin()
	config.Consumer.Offsets.Initial = sarama.OffsetNewest
	config.Consumer.Offsets.AutoCommit.Enable = true
	config.Consumer.Return.Errors = true

	return config
}

// Start begins consuming messages
func (c *Consumer) Start(ctx context.Context) error {
	for {
		select {
		case <-ctx.Done():
			c.logger.Info("Consumer context cancelled, stopping...")
			return nil
		default:
			if err := c.client.Consume(ctx, c.topics, c.handler); err != nil {
				c.logger.Error("Error consuming messages", zap.Error(err))
				return err
			}
		}
	}
}

// Close closes the consumer
func (c *Consumer) Close() error {
	return c.client.Close()
}
