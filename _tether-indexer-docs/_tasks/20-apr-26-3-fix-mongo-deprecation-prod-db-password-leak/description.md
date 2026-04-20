# Description

```
{job="pm2", level!="20"} |= "[DEP0170] DeprecationWarning: The URL mongodb"

{job="pm2", level!="20", service_name=~"idx-xaut-arb-api.+"} |= "[DEP0170] DeprecationWarning: The URL mongodb"
```

PROD Grafana Loki Queries

STAGING EQUIVALENT:

```
{agent="alloy", env="staging", level!="20"} |= "DeprecationWarning: The URL mongodb"
```

Note: an indexer needs to be restarted for the log to appear

## Leak DB password

```
[DEP0170] DeprecationWarning: The URL mongodb://wallet:XXXXXX@....
```

XXXXX will contain the leaked DB password

Please address this as this happened in production during a deployment and Rumble had to rotate the db password as people from the Tether team saw the prod db password.

===

Vigan suggested we use https://github.com/bitfinexcom/bfx-facs-db-mongo/tree/feature/mongodb-v6-driver
