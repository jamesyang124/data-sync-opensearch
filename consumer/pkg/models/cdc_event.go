package models

import (
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"time"
)

// CDCEvent represents a Debezium CDC event envelope
type CDCEvent struct {
	Payload Payload `json:"payload"`
}

// UnmarshalJSON accepts both Debezium JSON shapes:
// - schemaless converter: {"before":...,"after":...,"op":"c",...}
// - schema envelope: {"payload":{"before":...,"after":...,"op":"c",...}}
func (e *CDCEvent) UnmarshalJSON(data []byte) error {
	var raw struct {
		Payload     *Payload               `json:"payload"`
		Before      map[string]interface{} `json:"before"`
		After       map[string]interface{} `json:"after"`
		Source      Source                 `json:"source"`
		Op          string                 `json:"op"`
		TsMs        int64                  `json:"ts_ms"`
		Transaction *Transaction           `json:"transaction,omitempty"`
	}

	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}

	if raw.Payload != nil {
		e.Payload = *raw.Payload
		return nil
	}

	e.Payload = Payload{
		Before:      raw.Before,
		After:       raw.After,
		Source:      raw.Source,
		Op:          raw.Op,
		TsMs:        raw.TsMs,
		Transaction: raw.Transaction,
	}
	return nil
}

// Payload contains the CDC event data
type Payload struct {
	Before      map[string]interface{} `json:"before"`
	After       map[string]interface{} `json:"after"`
	Source      Source                 `json:"source"`
	Op          string                 `json:"op"`    // c (create), u (update), d (delete), r (read)
	TsMs        int64                  `json:"ts_ms"` // Timestamp in milliseconds
	Transaction *Transaction           `json:"transaction,omitempty"`
}

// Source contains metadata about the source database
type Source struct {
	Version   string      `json:"version"`
	Connector string      `json:"connector"`
	Name      string      `json:"name"`
	TsMs      int64       `json:"ts_ms"`
	Snapshot  interface{} `json:"snapshot"`
	Db        string      `json:"db"`
	Schema    string      `json:"schema"`
	Table     string      `json:"table"`
	TxID      int64       `json:"txId,omitempty"`
	Lsn       int64       `json:"lsn,omitempty"`
	Xmin      int64       `json:"xmin,omitempty"`
}

// Transaction contains transaction metadata
type Transaction struct {
	ID                  string `json:"id"`
	TotalOrder          int64  `json:"total_order"`
	DataCollectionOrder int64  `json:"data_collection_order"`
}

// GetStringField safely extracts a string field from a map
func GetStringField(data map[string]interface{}, key string) string {
	if val, ok := data[key]; ok {
		switch v := val.(type) {
		case string:
			return v
		case json.Number:
			return v.String()
		case float64:
			if math.Trunc(v) == v {
				return strconv.FormatInt(int64(v), 10)
			}
			return strconv.FormatFloat(v, 'f', -1, 64)
		case int64:
			return strconv.FormatInt(v, 10)
		case int:
			return strconv.Itoa(v)
		case nil:
			return ""
		default:
			str, ok := val.(fmt.Stringer)
			if ok {
				return str.String()
			}
		}
	}
	return ""
}

// GetTimestampField returns timestamps as RFC3339Nano strings for OpenSearch date fields.
// Debezium PostgreSQL schemaless timestamps commonly arrive as microseconds.
func GetTimestampField(data map[string]interface{}, key string) string {
	if val, ok := data[key]; ok {
		switch v := val.(type) {
		case string:
			return v
		case json.Number:
			if i, err := v.Int64(); err == nil {
				return formatEpochTimestamp(i)
			}
		case float64:
			return formatEpochTimestamp(int64(v))
		case int64:
			return formatEpochTimestamp(v)
		case int:
			return formatEpochTimestamp(int64(v))
		case nil:
			return ""
		}
	}
	return ""
}

func formatEpochTimestamp(value int64) string {
	switch {
	case value <= 0:
		return ""
	case value > 1_000_000_000_000_000_000:
		return time.Unix(0, value).UTC().Format(time.RFC3339Nano)
	case value > 1_000_000_000_000_00:
		return time.Unix(0, value*int64(time.Microsecond)).UTC().Format(time.RFC3339Nano)
	case value > 1_000_000_000_00:
		return time.Unix(0, value*int64(time.Millisecond)).UTC().Format(time.RFC3339Nano)
	default:
		return time.Unix(value, 0).UTC().Format(time.RFC3339Nano)
	}
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
