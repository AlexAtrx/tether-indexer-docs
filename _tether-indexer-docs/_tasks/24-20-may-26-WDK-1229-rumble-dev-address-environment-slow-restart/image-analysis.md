# Image analysis

## 1213475123348186-screenshot-2026-02-28-at-17.11.48.png

**Source comment:** Task description (Francesco Canessa, referenced inline as
`get_asset?asset_id=1213475123348186` right after the "I don't think we should
scale the Dev env more than what we already have" note).

**What it shows:** A "Compute Resources" table listing the DEV-environment
servers' hardware (Server / CPU / RAM / Disk / OS columns). The screenshot
appears cropped — only the header row and the first server row are clearly
visible in the rendering at hand, with the next row partially cut off.

**Key content (verbatim from the visible portion):**
- Table header: `Server | CPU | RAM | Disk | OS`
- Row 1: `wdk-dev-0`, CPU **8**, RAM **31 GB**, Disk **193 GB**, OS **Ubuntu 24.04.2**
- Row 2 (partially visible): likely another `wdk-dev-*` server with CPU 8 (or
  similar), ~31 GB RAM, ~250 GB Disk, OS appears to start with "D…" (likely
  Debian) — readable parts are truncated in the cropped view; consult the
  original `images/1213475123348186-screenshot-2026-02-28-at-17.11.48.png` file
  for the full table.

**Relevance:** This is Francesco's evidence for the "don't scale the DEV env"
position. He is telling the assignee (Alex) that the available DEV hardware
(8 vCPU / 31 GB RAM per box) is the budget they have to work with — so the
30-minute restart cannot be fixed by throwing more nodes at the problem. The
fix has to come from the service set or boot sequence, not capacity. Read the
full file if you need the second/third row values when reasoning about how
many services fit per box.
