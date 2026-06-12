# Image analysis — WDK-1229

## 1213475123348186-screenshot-2026-02-28-at-17.11.48.png

**Source comment:** Task description — Francesco's note "I don't think we should
scale the Dev env more than what we already have - see screenshot".

**What it shows:** A "Compute Resources" table listing the dev/staging servers
and their hardware specs (Server / CPU / RAM / Disk / OS).

**Key content:**
- Header row: Server | CPU | RAM | Disk | OS
- `wdk-dev-0` — CPU **8**, RAM **31 GB**, Disk **193 GB**, OS **Ubuntu 24.04.2**
- A second row is cut off at the bottom of the capture (server name starts with
  `wdk-...`, likely a staging/indexer box; values appear to be ~8 CPU / ~31 GB
  RAM / ~250 GB disk / Debian — not fully legible).

**Relevance:** Francesco is making the point that the dev box is small and fixed
(8 vCPU / 31 GB) and should NOT be scaled up to solve the slow-restart problem.
This frames the ticket toward fixing the restart *mechanism* (kill_timeout,
SIGINT handling, restart script) rather than throwing more hardware at it, and/or
trimming which services run in dev. The screenshot is partial — the full
resource table is not captured.
