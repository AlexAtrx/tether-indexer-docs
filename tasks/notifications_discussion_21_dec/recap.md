# Notifications discussion recap (21 Dec)

## What's the issue

- Swap notifications are inconsistent: some users get duplicates, others get none.
- The inconsistency is tied to how devices are registered and how old notification addresses are handled, especially in v2.
- A recent PR tried to make address matching more forgiving (case differences), which may help some misses but does not solve device/registration reliability.

## What's eventually wanted by the team

- If a user has multiple devices, all of them should reliably receive swap notifications.
- Each device should have one current notification address, and outdated ones should be cleaned up.
- Clear, consistent rules on which device record is the “current” one when re-registering.

## Decision proposal (non-technical)

### Backend

- Keep a device list per user and treat each device as unique using a stable device identifier (implemented in backend).
- For each device, keep only the newest notification address and use that for sending (partially implemented).
- Send to every device on the list, and remove addresses that are rejected by the push service (Send-to-all is implemented; cleanup on rejected tokens is not).
- Periodically remove devices that have been inactive for a long time (not implemented).

### Frontend (mobile)

- Always send the current notification address on app start, after login, and whenever it changes.
- Always include the stable device identifier so the backend can replace the old address for that same device.
- Ensure only one active notification address exists per device (replace the old one on refresh/reinstall).
