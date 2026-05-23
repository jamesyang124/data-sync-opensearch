package opensearch

import "testing"

func TestIsStaleDocumentUsesSourceTimestampBeforeUpdatedAt(t *testing.T) {
	incoming := map[string]interface{}{
		"source_ts_ms": int64(100),
		"updated_at":   "2026-05-24T10:00:00Z",
	}
	existing := map[string]interface{}{
		"source_ts_ms": int64(200),
		"updated_at":   "2026-05-24T09:00:00Z",
	}

	if !isStaleDocument(incoming, existing) {
		t.Fatal("expected lower Debezium source timestamp to be stale")
	}
}

func TestIsStaleDocumentFallsBackToUpdatedAt(t *testing.T) {
	incoming := map[string]interface{}{"updated_at": "2026-05-24T09:00:00Z"}
	existing := map[string]interface{}{"updated_at": "2026-05-24T10:00:00Z"}

	if !isStaleDocument(incoming, existing) {
		t.Fatal("expected older updated_at to be stale")
	}
}

func TestIsStaleDocumentAcceptsNewerChange(t *testing.T) {
	incoming := map[string]interface{}{
		"source_ts_ms": float64(300),
		"updated_at":   "2026-05-24T10:00:00Z",
	}
	existing := map[string]interface{}{
		"source_ts_ms": float64(200),
		"updated_at":   "2026-05-24T11:00:00Z",
	}

	if isStaleDocument(incoming, existing) {
		t.Fatal("expected higher Debezium source timestamp to be accepted")
	}
}

func TestIsStaleDeleteRejectsOlderDelete(t *testing.T) {
	existing := map[string]interface{}{"source_ts_ms": int64(300)}

	if !isStaleDelete(200, existing) {
		t.Fatal("expected lower delete source timestamp to be stale")
	}
}

func TestIsStaleDeleteAcceptsNewerDelete(t *testing.T) {
	existing := map[string]interface{}{"source_ts_ms": int64(300)}

	if isStaleDelete(400, existing) {
		t.Fatal("expected higher delete source timestamp to be accepted")
	}
}
