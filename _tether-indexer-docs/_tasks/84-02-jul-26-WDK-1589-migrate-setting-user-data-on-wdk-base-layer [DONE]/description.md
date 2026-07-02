# Description (raw)

Task related to https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215365454673850?focus=true

(That link is WDK-1522 "Support setting multiple user-data keys in one request",
local folder `_tasks/83-01-jul-26-WDK-1522-support-setting-multiple-user-data-keys-in-one-request [DONE]/`.)

The description is one line — the real scope was agreed in the Slack thread Alex started
(see `slack-context.md`): lift the duplicated user-data key/value API out of the
`tether-wallet-*` and `rumble-*` forks into the `wdk-*` base layer so both forks inherit
one implementation, keeping the TW-only immutable seeds/entropies handling in the
tether-wallet fork.
