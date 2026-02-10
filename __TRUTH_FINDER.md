Think deeply about this and take all the time you need.

## Task

- The directory `_docs` is a personal docs folder for this INDEXER project. This project is part of the WDK project. Tasks in `_docs/_tasks/` are dated — use dates to determine recency and relevance.

- This directory includes meeting minutes, stack documentation, findings, Slack conversations, and backend architecture information.

- I want you to write/update a single file (`___TRUTH.md`), which contains the 'truth' from an engineering perspective. The truth includes:
  • key architecture decisions
  • key features that are offered by the indexer as part of the WDK
  • key features that need to be in the WDK to be top industry standard
  • key features that can be good add-ons
  • key challenges and weak points
  • key security threats if any
  • key TODOs if any
  • any other notes or concerns or suggestions that can help from engineering perspectives.

## What to Read

Priority order (read ALL of these):

1. **Existing truth file**: `_docs/___TRUTH.md` — read first. Note its `Last Updated` date. Focus new effort on what changed since then.
2. **Root context files**: `CLAUDE.md`, `WARP.md`, `GEMINI.md` — architecture overview and setup instructions.
3. **All `_docs/` files** at root level (APP_RELATIONS.md, mapping.md, diagram_nodes.md, about_Tether.md, etc.)
4. **Diagrams**: `_docs/wdk-indexer-local-diagram.mmd` AND all `.mmd` files in `_docs/analysis-2026-01-14/` — these show architecture, data flow, and dependencies.
5. **Meeting minutes**: `_docs/minutes/`
6. **Tasks**: `_docs/_tasks/` — each subdirectory is a task. Prioritize tasks dated AFTER the truth file's last update.
7. **All repos** in this project:
   - README.md, package.json, config/ directories
   - `worker.js` (entry point)
   - `workers/lib/` directories — **this is where the real implementation lives** (RPC manager, metrics, proc/api workers, DB layer, chain clients)
   - Any `.md` files (METRICS.md, etc.)
8. **Docker setup**: `_wdk_docker_network_v2/` — docker-compose.yml, Makefile, README.md, scripts/
9. **Analysis reports**: `_docs/analysis-2026-01-14/` and any other analysis directories.
10. **App setup docs**: `_docs/app_setup/`

## Important

1- Be concise. Don't over-elaborate on any part.
2- Put all output in `_docs/___TRUTH.md` in a well-formatted way.
3- This task repeats at random intervals depending on updates, so make the output expandable/changeable.
4- Optimize the truth file for developer reading AND for LLM context on any project-related prompt.
5- **REMOVAL RULE (critical)**: After drafting the updated truth file, go section by section and verify every claim against actual source material (code, docs, tasks, meeting notes). If any issue or piece of info in the truth file is NOT reflected in the current docs, code, or any reading material listed above, it no longer exists and MUST be removed from the truth file. Do not keep stale information.
6- **VERIFICATION STEP**: Before finalizing, spot-check at least 5 specific claims by reading the actual source code or config. Confirm defaults, method names, cron schedules, feature flags, etc. are accurate.
7- Maintain the `Recent Changes` table — add new dated entries, keep the last ~10 entries, remove older ones.
8- Update the `Last Updated` date at the top of the truth file.
