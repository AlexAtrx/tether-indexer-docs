The dev says:

"
In staging environment: We have 3 providers. My understanding regarding circuit breaker is that:
If there are multiple providers, and one of the provider fails. Then it will open the circuit for that provider and won't forward requests to that provider for the next 30 seconds. Is this correct?
When I look at the logs, I don't see this behavior AFAIU.
"

Log: _docs/tasks/debug_ circuit_breaker_not_working_on_staging/log2.log
