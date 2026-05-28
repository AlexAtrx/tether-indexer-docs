# Description

Already in progress from shared repos - blocked by:

CARD ✓ Security - Chore - update fastify version
(https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213145412557891)

---

We are upgrading fastify to v5, and need to make sure all fastify plug ins are updated accordingly.

Here is an example of one plugin that needed to update:
https://github.com/tetherto/svc-facs-httpd/pull/8

```
"@fastify/static": "^6.10.2", —→  "@fastify/static": "^8.3.0",
```

Check the repos, both internal and rumble, for what needs updating.

Assigned to Alex but can be passed to Usman if needed
