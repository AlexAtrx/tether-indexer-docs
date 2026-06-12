# Missing context

- [ ] **External tickets:** "Depends on the companion planning card." — **Need from Alex:** the Asana URL / WDK number of the planning card this implementation card depends on. The ticket says it exists but does not link it; the planning card almost certainly holds the actual design (campaign config schema, API surface, refactor scope). **Source:** description.
- [ ] **Blocked status:** the `Blocked?` custom field is set to **BLOCKED**, but no reason is recorded on the ticket. — **Need from Alex:** what this is blocked on (the planning card not being finished? a dependency? a decision?). **Source:** custom field.
- [ ] **Scope / acceptance:** the description is a one-liner with no acceptance criteria, no list of which API endpoints or which promo-worker behaviours change, and no definition of "configurable multi-campaign." — **Need from Alex:** point to the planning card or a spec; otherwise the implementation scope is undefined. **Source:** description.

Context worth noting for whoever picks this up: this is the multi-campaign generalisation of the existing single-campaign promo flow. Prior promo-worker / app-node deploy work is captured in `[[project_staging_deploy_promo]]` (promo-wrk singleton on walletstg1, the `amountPerClaim` test tweak, the box-git-pull bundle workaround) — that is the current single-campaign baseline this refactor builds on.
