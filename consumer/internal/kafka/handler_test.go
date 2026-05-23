package kafka

import (
	"errors"
	"testing"

	"github.com/IBM/sarama"
	"go.uber.org/zap"
)

type fakeDLQPublisher struct {
	err       error
	published bool
}

func (f *fakeDLQPublisher) PublishToDLQ(
	originalTopic string,
	originalPartition int32,
	originalOffset int64,
	originalKey []byte,
	originalValue []byte,
	errorMsg string,
	attemptCount int,
) error {
	f.published = true
	return f.err
}

func TestHandleProcessingFailureMarksOnlyAfterDLQPublishSucceeds(t *testing.T) {
	handler := NewMessageHandler(zap.NewNop(), nil, nil, nil)
	successDLQ := &fakeDLQPublisher{}
	handler.SetDLQProducer(successDLQ)

	shouldMark := handler.handleProcessingFailure(&sarama.ConsumerMessage{}, errors.New("bad message"))
	if !shouldMark {
		t.Fatal("expected poison message to be markable after DLQ publish succeeds")
	}
	if !successDLQ.published {
		t.Fatal("expected DLQ publish attempt")
	}

	failingDLQ := &fakeDLQPublisher{err: errors.New("kafka unavailable")}
	handler.SetDLQProducer(failingDLQ)

	shouldMark = handler.handleProcessingFailure(&sarama.ConsumerMessage{}, errors.New("bad message"))
	if shouldMark {
		t.Fatal("did not expect message to be markable when DLQ publish fails")
	}
}
