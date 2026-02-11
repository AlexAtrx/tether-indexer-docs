<!-- This description is concluded from some meeting notes and team discussions. It does not represent necessarily the final design of the login point. The design and the specification decision of this NPowan should pretty much depend on the actual system and it should be made after reviewing all code bases and understanding the best way to handle the logs. -->

# `/logs` Endpoint – Backend & Operational Design

The `/logs` API is designed to provide reliable, secure, and scalable client-side log ingestion while preserving system performance and end-to-end traceability. The solution must balance **observability**, **abuse prevention**, and **operational safety**.

---

## 1. Dual-Mode Access

The endpoint must support both:

### Authenticated users

- Requests include a valid JWT
- Logs are associated with `userId` or `walletId`

### Unauthenticated users

- Requests include a temporary `deviceId` or `sessionId`
- Enables correlation without requiring authentication

This ensures visibility across the full user journey, including pre-login flows.

---

## 2. Payload Structure

Each log entry should contain:

**Required**

- `traceId` – for end-to-end correlation
- `logLevel` – e.g. info, warn, error
- `message` – human-readable log message

**Conditional identity**

- `userId` or `walletId` (authenticated)
- `deviceId` / `sessionId` (unauthenticated)

**Optional metadata**

- `device`
- `appVersion`
- `timestamp` (backend may override or enrich)

---

## 3. Rate Limiting & Abuse Protection

To prevent spam, misuse, or compromised front-end flooding:

- Enforce **per-user** limits for authenticated requests
- Enforce **per-device/session** limits for unauthenticated requests
- Use **Redis-based counters**
- Apply strict thresholds for high-frequency logging

This protects both infrastructure and observability systems.

---

## 4. Ingestion Pipeline Options

Two ingestion strategies are supported:

### Option A – Direct Push (Initial Phase)

- Backend forwards logs straight to **Grafana/Loki**
- Simple and fast to implement

### Option B – Buffered Ingestion (Scalable Phase)

- Logs are sent to a **queue/stream** (Kafka, Redis Streams, etc.)
- Workers batch and forward logs asynchronously
- Provides:

  - Backpressure control
  - Higher resilience
  - Better scalability

---

## 5. Performance Isolation

Logging must **never impact core API performance**.

To ensure this:

- Log ingestion is handled **asynchronously**
- Forwarding to Grafana/Loki happens in a **worker or background process**
- Batching is preferred over per-log network calls

The API remains responsive even under heavy logging load.

---

## 6. Trace Propagation

The `traceId` must be preserved across all backend layers:

- ork
- data-shard
- indexer

This enables:

- End-to-end request tracing
- Cross-service debugging
- Correlated error analysis

Every system component must forward the same `traceId`.

---

## 7. Backend Enrichment

Before forwarding logs, the backend should:

- Attach a trusted timestamp
- Normalize device and app version fields
- Ensure identity fields are consistent
- Optionally add environment/service tags

This guarantees clean, structured observability data.

---

## 8. Design Principles

The `/logs` endpoint should be:

- **Lightweight** – minimal overhead per request
- **Resilient** – tolerant to spikes and failures
- **Rate-controlled** – protected against abuse
- **Trace-aware** – full request visibility
- **Non-blocking** – isolated from core API paths

The goal is **maximum observability with minimal risk**.
