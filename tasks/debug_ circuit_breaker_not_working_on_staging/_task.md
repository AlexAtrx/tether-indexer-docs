## Context

This is a task that has been done \_docs/tasks/add_circuit_breaker_and_failover_ordering

These are the repos to perform this task:
https://github.com/tetherto/wdk-indexer-wrk-base/pull/57
https://github.com/tetherto/wdk-indexer-wrk-btc/pull/59
https://github.com/tetherto/wdk-indexer-wrk-evm/pull/55
https://github.com/tetherto/wdk-indexer-wrk-solana/pull/42
https://github.com/tetherto/wdk-indexer-wrk-ton/pull/54
https://github.com/tetherto/wdk-indexer-wrk-tron/pull/51

Yet we are getting a message from the dev:
"
I am noticing errors on staging like follows, which signify that ankr provider api key has expired. So, I am removing this key from the staging environment. This is populating too many errors in staging.
"

And the is in _docs/tasks/debug_ circuit_breaker_not_working_on_staging/log.log

And a question:
"
i am also a bit confused here because staging includes circuit breaker code that you recently implemented, but there are tons of error logs for ankr. Shouldn't our code prevent repeated calls to this provider?
"

## Task

- Check the circuit breaker task; check its repos; check the local code changes corresponding to it. Locally you should be on 'staging' branch for all the relevant repos. If not, fetch it from the remote 'https://github.com/tetherto...'

- Check the log message and tell me if the circuit breaker feature is designed to avoid such behavior or not.

- Explain why this behavior is not avoided although the circuit breaker is implemented. Double check the log to make sure it does reflect the changes implemented in the PR. If you think they don't, tell!

- Find out the root of the problem.
