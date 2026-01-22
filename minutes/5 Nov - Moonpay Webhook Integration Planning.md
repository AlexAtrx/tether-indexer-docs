# Moonpay Webhook Integration Planning

## Action Items

- Loop Alex in when you receive logs or updates from Andrea’s side.
- Confirm with Moonpay whether their webhook payload includes transaction hash or wallet address.
- Email Moonpay to request the correct webhook documentation link and clarify needed payload fields.
- Add a timeout setting to the MongoDB database layer to prevent lock‑wait hangs.
- Review and test the new MongoDB timeout change; get a MongoDB‑experienced teammate to review.
- Restart the affected indexer worker now to clear the current issue.
- Ping Andrea again to secure access to production Grafana dashboards or logs; tag Alex for escalation if needed.
- Assign and open task **wdk610-1-2** (Enable GitHub Actions tests for wdk rumble budgets) in the tracker.
- If no response from Jesse on pending test, tag Jesse and Mario to apply pressure.

## Moonpay Integration

- Cache Moonpay transaction statuses periodically instead of querying on every API call.
- Sync Moonpay data asynchronously via a background worker that updates purchase flags.
- Use webhook payload identifiers to map transactions before implementing any logic.
- Consider adding a custom label to transactions in our DB after receiving webhook events.
- Heavy real‑time calls to Moonpay status endpoint could add latency; prefer webhook‑based labeling.

## Indexer & Data Shard Issues

- One indexer worker stopped fetching logs; restarting it resumed recent data.
- Some transactions appeared in the indexer but were missing from the token‑transfers endpoint.
- Data shard worker also missed its sync job, causing similar gaps.
- Root cause suspected: RPC requests have timeouts, but DB lock waits have none.

## MongoDB Timeout Fix

- Implement timeout for DB lock acquisition to avoid indefinite hangs.
- Seek MongoDB‑savvy colleague to review the change and help with testing.

## Grafana & Production Logs

- Production Grafana setup pending; need clarification on dashboard access.
- Andrea to discuss with team whether to integrate into existing dashboards.
- Ensure the team has proper access to production logs for Rumble wallet backend.

## Testing Automation & CI

- Alerts now configured in Grafana; one blocker remains from “cheetahs”.
- Proposed workflow on NA Tensor to replace bash scripts with Ansible.
- Enable GitHub Actions tests for wdk rumble budgets (task wdk610-1-2).

## Team Coordination

- Alex offered to join joint debugging sessions and help with repo onboarding.
- Usman to reach out after call to schedule collaboration.
- Nicolaus has two blockers pending test from Chatos; follow up if no response today.
- Rumble backend needs transaction categorization for metrics; decision pending on who implements (Rumble vs our side).

## Miscellaneous

- Search icon on toolbar helps locate tasks by name/number in the tracker.
- Keep communication clear when requesting access or clarifications to avoid delays.