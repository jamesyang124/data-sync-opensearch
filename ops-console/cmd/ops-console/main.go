package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"sync"
	"time"
)

type config struct {
	addr                string
	workdir             string
	composeBin          string
	composeProjectName  string
	benchmarkImage      string
	producerURL         string
	consumerURL         string
	kafbatURL           string
	kafkaUIURL          string
	openSearchURL       string
	openSearchDashboard string
	benchmarkReportPath string
	kafkaConsumerGroup  string
}

type server struct {
	cfg          config
	mu           sync.Mutex
	benchmarkRun *benchmarkRun
}

type pageData struct {
	KafbatURL           string
	KafkaUIURL          string
	OpenSearchDashboard string
	BenchmarkReportPath string
}

type benchmarkRun struct {
	ID        string    `json:"id"`
	Scenario  string    `json:"scenario"`
	TargetRPS int       `json:"target_rps"`
	Duration  string    `json:"duration"`
	StartedAt time.Time `json:"started_at"`
	EndedAt   time.Time `json:"ended_at,omitempty"`
	Running   bool      `json:"running"`
	ExitCode  int       `json:"exit_code"`
	Output    string    `json:"output"`
	Error     string    `json:"error,omitempty"`
}

type probe struct {
	URL    string `json:"url"`
	Status int    `json:"status"`
	Error  string `json:"error,omitempty"`
}

type scaleRequest struct {
	Replicas int `json:"replicas"`
}

type benchmarkRequest struct {
	Scenario         string `json:"scenario"`
	TargetRPS        int    `json:"target_rps"`
	Duration         string `json:"duration"`
	ConsumerReplicas int    `json:"consumer_replicas"`
	SetupUsers       int    `json:"setup_users"`
	SetupVideos      int    `json:"setup_videos"`
	SetupComments    int    `json:"setup_comments"`
}

func main() {
	cfg := loadConfig()
	s := &server{cfg: cfg}

	mux := http.NewServeMux()
	mux.HandleFunc("/", s.handleIndex)
	mux.HandleFunc("/api/status", s.handleStatus)
	mux.HandleFunc("/api/scale", s.handleScale)
	mux.HandleFunc("/api/benchmark", s.handleBenchmark)
	mux.HandleFunc("/api/benchmark/last", s.handleBenchmarkLast)

	log.Printf("ops console listening on %s", cfg.addr)
	if err := http.ListenAndServe(cfg.addr, mux); err != nil {
		log.Fatal(err)
	}
}

func loadConfig() config {
	return config{
		addr:                env("OPS_CONSOLE_ADDR", ":8090"),
		workdir:             env("OPS_CONSOLE_WORKDIR", "/workspace"),
		composeBin:          env("OPS_CONSOLE_COMPOSE_BIN", "docker"),
		composeProjectName:  env("OPS_CONSOLE_COMPOSE_PROJECT_NAME", "data-sync-opensearch"),
		benchmarkImage:      env("OPS_CONSOLE_BENCHMARK_IMAGE", "data-sync/benchmark:latest"),
		producerURL:         env("OPS_CONSOLE_PRODUCER_URL", "http://producer:8080"),
		consumerURL:         env("OPS_CONSOLE_CONSUMER_URL", "http://consumer:8080"),
		kafbatURL:           env("OPS_CONSOLE_KAFBAT_URL", "http://localhost:8084"),
		kafkaUIURL:          env("OPS_CONSOLE_KAFKA_UI_URL", "http://localhost:8081"),
		openSearchURL:       env("OPS_CONSOLE_OPENSEARCH_URL", "http://opensearch:9200"),
		openSearchDashboard: env("OPS_CONSOLE_OPENSEARCH_DASHBOARD_URL", "http://localhost:5601"),
		benchmarkReportPath: env("OPS_CONSOLE_BENCHMARK_REPORT_PATH", "/workspace/benchmark/reports"),
		kafkaConsumerGroup:  env("OPS_CONSOLE_CONSUMER_GROUP", "cdc-consumer-group"),
	}
}

func env(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func (s *server) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_ = pageTemplate.Execute(w, pageData{
		KafbatURL:           s.cfg.kafbatURL,
		KafkaUIURL:          s.cfg.kafkaUIURL,
		OpenSearchDashboard: s.cfg.openSearchDashboard,
		BenchmarkReportPath: s.cfg.benchmarkReportPath,
	})
}

func (s *server) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	probes := map[string]probe{
		"producer_health":  s.probe(ctx, s.cfg.producerURL+"/health"),
		"producer_metrics": s.probe(ctx, s.cfg.producerURL+"/metrics"),
		"consumer_health":  s.probe(ctx, s.cfg.consumerURL+"/health"),
		"consumer_metrics": s.probe(ctx, s.cfg.consumerURL+"/metrics"),
		"opensearch":       s.probe(ctx, s.cfg.openSearchURL),
	}

	psOut, psErr := s.compose(ctx, "ps")
	kafkaGroupOut, kafkaGroupErr := s.compose(ctx,
		"exec", "-T", "kafka",
		"kafka-consumer-groups",
		"--bootstrap-server", "kafka:9092",
		"--describe",
		"--group", s.cfg.kafkaConsumerGroup,
	)
	response := map[string]interface{}{
		"probes":         probes,
		"compose_ps":     psOut,
		"compose_error":  psErr,
		"last_benchmark": s.lastBenchmark(),
		"kafka_consumer_group": map[string]string{
			"group":  s.cfg.kafkaConsumerGroup,
			"output": kafkaGroupOut,
			"error":  kafkaGroupErr,
		},
		"links": map[string]string{
			"kafbat":                s.cfg.kafbatURL,
			"kafka_ui":              s.cfg.kafkaUIURL,
			"opensearch_dashboards": s.cfg.openSearchDashboard,
		},
	}
	writeJSON(w, http.StatusOK, response)
}

func (s *server) probe(ctx context.Context, url string) probe {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return probe{URL: url, Error: err.Error()}
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return probe{URL: url, Error: err.Error()}
	}
	defer res.Body.Close()
	io.Copy(io.Discard, res.Body)
	return probe{URL: url, Status: res.StatusCode}
}

func (s *server) handleScale(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req scaleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}
	if req.Replicas < 1 || req.Replicas > 20 {
		http.Error(w, "replicas must be between 1 and 20", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Minute)
	defer cancel()
	out, errMsg := s.compose(ctx, "--profile", "app", "up", "-d", "--scale", fmt.Sprintf("consumer=%d", req.Replicas))
	if errMsg != "" {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": errMsg, "output": out})
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"replicas": req.Replicas, "output": out})
}

func (s *server) handleBenchmark(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req benchmarkRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}
	req.applyDefaults()
	if err := req.validate(); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	s.mu.Lock()
	if s.benchmarkRun != nil && s.benchmarkRun.Running {
		current := *s.benchmarkRun
		s.mu.Unlock()
		writeJSON(w, http.StatusConflict, current)
		return
	}
	run := &benchmarkRun{
		ID:        fmt.Sprintf("bench-%d", time.Now().Unix()),
		Scenario:  req.Scenario,
		TargetRPS: req.TargetRPS,
		Duration:  req.Duration,
		StartedAt: time.Now(),
		Running:   true,
		ExitCode:  -1,
	}
	s.benchmarkRun = run
	s.mu.Unlock()

	go s.runBenchmark(req, run)
	writeJSON(w, http.StatusAccepted, run)
}

func (s *server) handleBenchmarkLast(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, http.StatusOK, s.lastBenchmark())
}

func (s *server) runBenchmark(req benchmarkRequest, run *benchmarkRun) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
	defer cancel()

	var combined bytes.Buffer
	if req.ConsumerReplicas > 0 {
		out, errMsg := s.compose(ctx, "--profile", "app", "up", "-d", "--scale", fmt.Sprintf("consumer=%d", req.ConsumerReplicas))
		combined.WriteString("== scale consumer ==\n")
		combined.WriteString(out)
		if errMsg != "" {
			s.finishBenchmark(run, 1, combined.String(), errMsg)
			return
		}
	}

	networkName := s.cfg.composeProjectName + "_default"
	args := []string{
		"run", "--rm",
		"--network", networkName,
		"-v", s.cfg.workdir + "/benchmark/scripts:/scripts:ro",
		"-v", s.cfg.workdir + "/benchmark/reports:/reports",
		"-e", "BENCHMARK_SCENARIO=" + req.Scenario,
		"-e", "BENCHMARK_TARGET_RPS=" + strconv.Itoa(req.TargetRPS),
		"-e", "BENCHMARK_DURATION=" + req.Duration,
		"-e", "BENCHMARK_SETUP_USERS=" + strconv.Itoa(req.SetupUsers),
		"-e", "BENCHMARK_SETUP_VIDEOS=" + strconv.Itoa(req.SetupVideos),
		"-e", "BENCHMARK_SETUP_COMMENTS=" + strconv.Itoa(req.SetupComments),
		s.cfg.benchmarkImage,
		"run", "/scripts/main.js", "--out", "json=/reports/" + req.Scenario + "-raw.ndjson",
	}
	cmd := exec.CommandContext(ctx, s.cfg.composeBin, args...)
	cmd.Dir = s.cfg.workdir
	cmd.Env = os.Environ()
	out, err := cmd.CombinedOutput()
	combined.WriteString("\n== benchmark ==\n")
	combined.Write(out)
	if err != nil {
		s.finishBenchmark(run, exitCode(err), combined.String(), err.Error())
		return
	}
	s.finishBenchmark(run, 0, combined.String(), "")
}

func (s *server) finishBenchmark(run *benchmarkRun, code int, output, errMsg string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	run.EndedAt = time.Now()
	run.Running = false
	run.ExitCode = code
	run.Output = tail(output, 24000)
	run.Error = errMsg
}

func (s *server) compose(ctx context.Context, args ...string) (string, string) {
	fullArgs := append([]string{"compose", "-p", s.cfg.composeProjectName}, args...)
	cmd := exec.CommandContext(ctx, s.cfg.composeBin, fullArgs...)
	cmd.Dir = s.cfg.workdir
	cmd.Env = os.Environ()
	out, err := cmd.CombinedOutput()
	if err != nil {
		return string(out), err.Error()
	}
	return string(out), ""
}

func (s *server) lastBenchmark() *benchmarkRun {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.benchmarkRun == nil {
		return nil
	}
	copy := *s.benchmarkRun
	return &copy
}

func (r *benchmarkRequest) applyDefaults() {
	if r.Scenario == "" {
		r.Scenario = "sustained"
	}
	if r.TargetRPS == 0 {
		r.TargetRPS = 20
	}
	if r.Duration == "" {
		r.Duration = "30s"
	}
	if r.SetupUsers == 0 {
		r.SetupUsers = 50
	}
	if r.SetupVideos == 0 {
		r.SetupVideos = 25
	}
	if r.SetupComments == 0 {
		r.SetupComments = 25
	}
}

func (r benchmarkRequest) validate() error {
	switch r.Scenario {
	case "sustained", "ramp-up", "stress":
	default:
		return errors.New("scenario must be sustained, ramp-up, or stress")
	}
	if r.TargetRPS < 1 || r.TargetRPS > 2000 {
		return errors.New("target_rps must be between 1 and 2000")
	}
	if !validDuration(r.Duration) {
		return errors.New("duration must look like 30s, 2m, or 1h")
	}
	if r.ConsumerReplicas < 0 || r.ConsumerReplicas > 20 {
		return errors.New("consumer_replicas must be between 0 and 20")
	}
	if r.SetupUsers < 10 || r.SetupVideos < 5 || r.SetupComments < 5 {
		return errors.New("setup pools must be at least users=10, videos=5, comments=5")
	}
	return nil
}

func validDuration(value string) bool {
	if len(value) < 2 {
		return false
	}
	_, err := time.ParseDuration(value)
	return err == nil
}

func exitCode(err error) int {
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return exitErr.ExitCode()
	}
	return 1
}

func tail(value string, limit int) string {
	if len(value) <= limit {
		return value
	}
	return value[len(value)-limit:]
}

func writeJSON(w http.ResponseWriter, status int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

var pageTemplate = template.Must(template.New("index").Parse(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Data Sync Ops Console</title>
  <style>
    :root { color-scheme: light dark; font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    body { margin: 0; background: #f7f8fa; color: #15171a; }
    header { background: #0f172a; color: #fff; padding: 18px 24px; }
    main { padding: 20px 24px; display: grid; gap: 16px; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); }
    section { background: #fff; border: 1px solid #d8dde6; border-radius: 8px; padding: 16px; box-shadow: 0 1px 2px rgba(15, 23, 42, 0.05); }
    h1 { margin: 0; font-size: 22px; }
    h2 { margin: 0 0 12px; font-size: 16px; }
    label { display: grid; gap: 4px; margin: 10px 0; font-size: 13px; color: #334155; }
    input, select, button { font: inherit; padding: 8px 10px; border: 1px solid #cbd5e1; border-radius: 6px; background: #fff; color: #111827; }
    button { cursor: pointer; background: #2563eb; color: #fff; border-color: #2563eb; font-weight: 600; }
    button.secondary { background: #fff; color: #1f2937; border-color: #cbd5e1; }
    a { color: #1d4ed8; text-decoration: none; }
    pre { white-space: pre-wrap; max-height: 420px; overflow: auto; background: #0f172a; color: #e5e7eb; padding: 12px; border-radius: 6px; font-size: 12px; }
    .links { display: grid; gap: 8px; }
  </style>
</head>
<body>
  <header>
    <h1>Data Sync Ops Console</h1>
  </header>
  <main>
    <section>
      <h2>Observe</h2>
      <div class="links">
        <a href="{{.KafbatURL}}" target="_blank">Kafbat UI</a>
        <a href="{{.KafkaUIURL}}" target="_blank">Kafka UI</a>
        <a href="{{.OpenSearchDashboard}}" target="_blank">OpenSearch Dashboards</a>
      </div>
      <p>Reports: <code>{{.BenchmarkReportPath}}</code></p>
      <button class="secondary" onclick="refreshStatus()">Refresh status</button>
    </section>

    <section>
      <h2>Scale Consumers</h2>
      <label>Consumer replicas <input id="replicas" type="number" min="1" max="20" value="2"></label>
      <button onclick="scaleConsumers()">Apply scale</button>
    </section>

    <section>
      <h2>Run Benchmark</h2>
      <label>Scenario
        <select id="scenario">
          <option value="sustained">sustained</option>
          <option value="ramp-up">ramp-up</option>
          <option value="stress">stress</option>
        </select>
      </label>
      <label>Target RPS <input id="targetRps" type="number" min="1" max="2000" value="20"></label>
      <label>Duration <input id="duration" value="30s"></label>
      <label>Consumer replicas before run <input id="benchReplicas" type="number" min="0" max="20" value="2"></label>
      <button onclick="runBenchmark()">Start benchmark</button>
    </section>

    <section style="grid-column: 1 / -1;">
      <h2>Status</h2>
      <pre id="status">Loading...</pre>
    </section>
  </main>

  <script>
    async function refreshStatus() {
      const res = await fetch('/api/status');
      document.getElementById('status').textContent = JSON.stringify(await res.json(), null, 2);
    }
    async function scaleConsumers() {
      const res = await fetch('/api/scale', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({replicas: Number(document.getElementById('replicas').value)})
      });
      document.getElementById('status').textContent = JSON.stringify(await res.json(), null, 2);
    }
    async function runBenchmark() {
      const res = await fetch('/api/benchmark', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          scenario: document.getElementById('scenario').value,
          target_rps: Number(document.getElementById('targetRps').value),
          duration: document.getElementById('duration').value,
          consumer_replicas: Number(document.getElementById('benchReplicas').value)
        })
      });
      document.getElementById('status').textContent = JSON.stringify(await res.json(), null, 2);
    }
    refreshStatus();
    setInterval(refreshStatus, 10000);
  </script>
</body>
</html>`))
