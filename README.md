# metrics-noise

Turns OpenTelemetry metrics into sound.

Each metric becomes an oscillator. As values change, notes shift within a pentatonic scale. Multiple metrics layer into evolving harmonics — a low drone for your baseline traffic, a mid voice for latency, a high shimmer for error rates. The result is an ambient, real-time sonification of whatever your system is doing.

Built with Phoenix LiveView for the UI and the Web Audio API for synthesis. No audio server or native deps required.

---

## How it works

```
instrumented app
      │
      │ OTLP (gRPC or HTTP)
      ▼
otel-collector
      │
      │ OTLP/HTTP JSON  POST /v1/metrics
      ▼
metrics-noise (Phoenix)
      │
      │ Phoenix PubSub
      ▼
LiveView → push_event → Web Audio API
```

Each incoming metric is tracked with a rolling min/max. The current value is normalized to `[0, 1]` and mapped to a note in the C major pentatonic scale. Up to four metrics occupy separate octave ranges (C2–A2, C3–A3, C4–A4, C5–A5), so they sit naturally in the mix without clashing.

The UI shows a live sparkline per metric and the current note being played.

---

## Running locally

```bash
mix setup
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000) and click **▶ START**.

---

## Sending metrics

The app accepts OTLP/HTTP with JSON encoding at `POST /v1/metrics`. This is standard OTLP — you just need to tell your exporter to use JSON encoding instead of protobuf.

**Shell helper for manual testing:**

```bash
metric() {
  curl -s -X POST http://localhost:4000/v1/metrics \
    -H "Content-Type: application/json" \
    -d "{\"resourceMetrics\":[{\"scopeMetrics\":[{\"metrics\":[{\"name\":\"$1\",\"gauge\":{\"dataPoints\":[{\"asDouble\":$2}]}}]}]}]}" \
    > /dev/null
}
```

**Establish a range, then play notes:**

```bash
# Seed min/max so the full note range is available
metric bass 0; metric bass 100

# Values 0/25/50/75/100 → C/D/E/G/A of that metric's octave
metric bass 0    # C2
metric bass 50   # E2
metric bass 100  # A2
```

**Three-voice chord:**

```bash
for name in bass mid high; do metric $name 0; metric $name 100; done
metric bass 25   # D2
metric mid 50    # E3
metric high 75   # G4
```

**Simulated app telemetry (continuous):**

```bash
metric http.duration 0; metric http.duration 500
metric jvm.memory 0; metric jvm.memory 1073741824
metric error.rate 0; metric error.rate 100

while true; do
  metric http.duration $((RANDOM % 500))
  metric jvm.memory $((200000000 + RANDOM * 10000))
  metric error.rate $((RANDOM % 20))
  sleep 0.5
done
```

---

## OTel Collector

To receive from real instrumented services, run an OpenTelemetry Collector with an `otlphttp` exporter pointed at this app:

```yaml
exporters:
  otlphttp:
    endpoint: http://localhost:4000
    encoding: json

service:
  pipelines:
    metrics:
      receivers: [otlp]
      exporters: [otlphttp]
```

The `encoding: json` flag is the only non-default setting. Everything else is standard collector configuration.

---

## TLS

`force_ssl` is intentionally disabled. This app sits behind a reverse proxy (Traefik, nginx, etc.) that handles TLS termination. Enabling it causes the app to redirect internal OTLP HTTP traffic to the public HTTPS hostname, breaking collector-to-app delivery.

If you expose this app directly without an ingress, re-enable it by uncommenting the block in [`config/prod.exs`](config/prod.exs).

---

## Deploying to Kubernetes

Prerequisites: a container registry, a cluster with the nginx ingress controller.

**Build and push:**

```bash
docker build -t your-registry/metrics-noise:latest .
docker push your-registry/metrics-noise:latest
```

**Configure before deploying:**

| File | What to change |
|------|----------------|
| `k8s/app/deployment.yaml` | Image name |
| `k8s/app/configmap.yaml` | `PHX_HOST` |
| `k8s/ingress.yaml` | `host` (must match `PHX_HOST`) |

**Generate and apply the secret:**

```bash
kubectl create secret generic metrics-noise-secrets \
  --namespace metrics-noise \
  --from-literal=SECRET_KEY_BASE=$(mix phx.gen.secret) \
  --dry-run=client -o yaml | kubectl apply -f -
```

**Apply manifests:**

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/app/
kubectl apply -f k8s/otel-collector/
kubectl apply -f k8s/ingress.yaml
```

**Instrumented apps send OTLP to:**

```
otel-collector.metrics-noise.svc.cluster.local:4317  # gRPC
otel-collector.metrics-noise.svc.cluster.local:4318  # HTTP
```

The collector receives standard OTLP from anything in the cluster and forwards metrics to metrics-noise as OTLP/HTTP JSON. Traces and logs are accepted but discarded; swap the `debug` exporter in `k8s/otel-collector/configmap.yaml` to route them somewhere useful.

---

## Note mapping

| Metric index | Octave | Notes |
|---|---|---|
| 0 | 2 | C2 D2 E2 G2 A2 |
| 1 | 3 | C3 D3 E3 G3 A3 |
| 2 | 4 | C4 D4 E4 G4 A4 |
| 3 | 5 | C5 D5 E5 G5 A5 |
| 4+ | wraps | — |

Metric index is assigned by arrival order. The first metric you send owns the bass voice.
