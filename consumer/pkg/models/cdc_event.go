package models

import "encoding/json"

// CDCEvent represents a Debezium CDC event envelope
type CDCEvent struct {
	Payload Payload `json:"payload"`
}

// Payload contains the CDC event data
type Payload struct {
	Before    map[string]interface{} `json:"before"`
	After     map[string]interface{} `json:"after"`
	Source    Source                  `json:"source"`
	Op        string                  `json:"op"`        // c (create), u (update), d (delete), r (read)
	TsMs      int64                   `json:"ts_ms"`     // Timestamp in milliseconds
	Transaction *Transaction          `json:"transaction,omitempty"`
}

// Source contains metadata about the source database
type Source struct {
	Version   string `json:"version"`
	Connector string `json:"connector"`
	Name      string `json:"name"`
	TsMs      int64  `json:"ts_ms"`
	Snapshot  string `json:"snapshot"`
	Db        string `json:"db"`
	Schema    string `json:"schema"`
	Table     string `json:"table"`
	TxID      int64  `json:"txId,omitempty"`
	Lsn       int64  `json:"lsn,omitempty"`
	Xmin      int64  `json:"xmin,omitempty"`
}

// Transaction contains transaction metadata
type Transaction struct {
	ID               string `json:"id"`
	TotalOrder       int64  `json:"total_order"`
	DataCollectionOrder int64 `json:"data_collection_order"`
}

// GetStringField safely extracts a string field from a map
func GetStringField(data map[string]interface{}, key string) string {
	if val, ok := data[key]; ok {
		if str, ok := val.(string); ok {
			return str
		}
	}
	return ""
}

// GetInt64Field safely extracts an int64 field from a map
func GetInt64Field(data map[string]interface{}, key string) int64 {
	if val, ok := data[key]; ok {
		switch v := val.(type) {
		case int64:
			return v
		case float64:
			return int64(v)
		case json.Number:
			if i, err := v.Int64(); err == nil {
				return i
			}
		}
	}
	return 0
}

// GetFloat64Field safely extracts a float64 field from a map
func GetFloat64Field(data map[string]interface{}, key string) float64 {
	if val, ok := data[key]; ok {
		switch v := val.(type) {
		case float64:
			return v
		case int64:
			return float64(v)
		case json.Number:
			if f, err := v.Float64(); err == nil {
				return f
			}
		}
	}
	return 0.0
}

// GetBoolField safely extracts a boolean field from a map
func GetBoolField(data map[string]interface{}, key string) bool {
	if val, ok := data[key]; ok {
		if b, ok := val.(bool); ok {
			return b
		}
	}
	return false
}
