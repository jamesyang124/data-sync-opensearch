package opensearch

import (
	"crypto/tls"
	"net/http"
	"time"

	opensearch "github.com/opensearch-project/opensearch-go/v2"
	"go.uber.org/zap"
)

// Client wraps OpenSearch client
type Client struct {
	client *opensearch.Client
	logger *zap.Logger
}

// NewClient creates a new OpenSearch client with retry logic
func NewClient(url string, logger *zap.Logger) (*Client, error) {
	retryBackoff := func(attempt int) time.Duration {
		return time.Duration(attempt) * time.Second
	}

	cfg := opensearch.Config{
		Addresses: []string{url},
		Transport: &http.Transport{
			MaxIdleConnsPerHost:   10,
			ResponseHeaderTimeout: 30 * time.Second,
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true, // For development only
			},
		},
		RetryOnStatus: []int{502, 503, 504, 429},
		RetryBackoff:  retryBackoff,
		MaxRetries:    3,
	}

	client, err := opensearch.NewClient(cfg)
	if err != nil {
		return nil, err
	}

	// Test connection
	res, err := client.Info()
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	logger.Info("Connected to OpenSearch", zap.String("url", url))

	return &Client{
		client: client,
		logger: logger,
	}, nil
}

// GetClient returns the underlying OpenSearch client
func (c *Client) GetClient() *opensearch.Client {
	return c.client
}
