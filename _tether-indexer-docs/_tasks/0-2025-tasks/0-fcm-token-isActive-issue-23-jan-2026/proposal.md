# Proposal: Remove `isLikelyFcmToken` Fallback Logic

## The Problem

Our device registration API currently accepts FCM tokens in two places: the `fcmToken` field (correct) or the `deviceId` field (incorrect but tolerated). When a client sends the FCM token in the wrong field, the backend uses a function called `isLikelyFcmToken` to guess whether the `deviceId` looks like an FCM token and uses it anyway. This was added to support legacy clients that were sending data incorrectly.

This guessing creates confusion and makes notification bugs hard to track down. When something goes wrong, we can't tell if the client sent bad data or if our logic failed, because the system silently "fixes" the input. The recent `isActive: false` bug investigation was harder because of this ambiguity.

## The Proposal

Remove the `isLikelyFcmToken` function and require clients to send the FCM token in the `fcmToken` field only. If they don't, the device simply won't receive push notifications, and the API response will clearly indicate `status: missing`. This makes the API predictable and forces clients to use it correctly.

## Warning

This is a breaking change. Any client currently sending FCM tokens as `deviceId` will stop receiving notifications until they update their integration. We need to coordinate with mobile teams and any external API consumers before rolling this out.
