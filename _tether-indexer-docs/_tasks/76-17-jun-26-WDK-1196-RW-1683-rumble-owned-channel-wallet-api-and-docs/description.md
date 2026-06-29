Parent: https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213303070214495

This is the app and docs slice of the parent split.

The point of this ticket is to make the public API ownership clear: WDK should not expose Rumble-specific channel wallet or tip-jar concepts, and Rumble should keep owning them.

this should be last, after storage and routing are already owned by Rumble.

Expected result:

- WDK app and docs are generic again.
- Rumble app and docs keep the channel wallet and tip-jar surface.
- The Rumble dependency can move to the cleaned WDK app-node version.
