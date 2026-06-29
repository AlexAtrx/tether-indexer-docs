Parent: https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213303070214495

This is the data-shard slice of the parent split.

The point of this ticket is to make the data-shard boundary clean: WDK should stay generic, and Rumble should own the Rumble-specific channel wallet behavior.

keep this one first. It is the storage layer, so it sets up the rest of the split.

Expected result:

- WDK data shard is no longer responsible for Rumble channel wallet behavior.
- Rumble data shard keeps the channel wallet and tip-jar behavior working.
- The Rumble dependency can move to the cleaned WDK data-shard version.

Note: HyperDB needs a reviewer decision before anyone removes generated schema/index material.
