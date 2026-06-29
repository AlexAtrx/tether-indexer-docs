Parent: https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213303070214495

This is the ork routing slice of the parent split.

The point of this ticket is to make Rumble own the channel-to-shard routing it needs for channel tip jars and channel wallet rename.

small sequencing note: this should follow the data-shard slice.

Expected result:

- WDK ork is generic again.
- Rumble ork owns the channel routing needed by Rumble wallet flows.
- The Rumble dependency can move to the cleaned WDK ork version.
