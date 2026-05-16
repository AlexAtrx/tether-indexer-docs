After Vigan's review let's create a migration to cleanup the orphaned results related to the issue below

SLACK CONTEXT
https://tether-to.slack.com/archives/C0A5DFYRNBB/p1778861994960789?thread_ts=1778859257.013279&cid=C0A5DFYRNBB


PREVIOUS TASK DESCRIPTION
TITLE: - Bugfix - purgeUserData doesn't reset deletedAt


NOTE: Rumble Related

when calling purgeUserData we don't reset deletedAt to 0 - this is a bug as wallet creation won't work properly if this deleted at field is not null


purgeUserData
https://github.com/tetherto/wdk-ork-wrk/blob/9d748c9f859083b78640865b724606aaf4051ac9/workers/api.ork.wrk.js#L300
https://github.com/tetherto/wdk-data-shard-wrk/blob/f69dbe8ac82b512e264c9fe5baf1644d5736b346/workers/proc.shard.data.wrk.js#L587



SLACK
https://tether-to.slack.com/archives/C0A5DFYRNBB/p1774905922216999?thread_ts=1774621065.566059&cid=C0A5DFYRNBB
