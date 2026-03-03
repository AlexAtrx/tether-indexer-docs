Two thousand persistent connections isn’t inherently abnormal if you have multiple app instances or a high concurrency workload, but it’s worth checking whether the pool size per instance is capped. If each service replica maintains its own pool, the total can easily add up. What matters more is whether those connections are active or idle and if the driver is recycling them properly.


You can get partial visibility here, but for detailed connection state—like active vs idle—you’d need to enable MongoDB’s connPoolStats command or use the driver’s connection monitoring hooks. That’ll show whether pools are being reused or recreated too frequently.

I’ll prepare a short list of diagnostic commands and metrics we need from production—mainly connPoolStats, driver version, and connection pool configuration. Once you loop in Andre, he can run them and share the outputs so we can pinpoint why the pool teardown is happening.
