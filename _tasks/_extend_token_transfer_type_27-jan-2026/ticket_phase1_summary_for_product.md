# Phase 1 Summary: Explicit Transaction Types for Tips & Rants

## The Problem

When Rumble users send tips or rants to live channels, the message sometimes never appears in chat. Users see a successful transaction, but the streamer and audience never see the tip notification.

This happens because the backend silently drops requests when certain data is missing. The mobile app believes the request succeeded, but the backend never creates the notification. There is no error message, no retry, and no way for anyone to know something went wrong.

## Why This Happens

Currently, all transfers (regular, tips, and rants) use the same request type. The backend tries to guess the user's intent based on which optional fields are present. When a field is missing, the backend assumes it's a regular transfer and skips the chat notification entirely.

## The Solution

Instead of guessing, we will require the mobile app to explicitly declare the transaction type:

- **Regular Transfer** — moving funds between wallets
- **Tip** — sending money to a channel (no message)
- **Rant** — sending money to a channel with a message

When the app declares "this is a tip" or "this is a rant," the backend will validate that all required information is present. If something is missing, the app receives an immediate error and can notify the user or retry.

## What This Means for Users

- Tips and rants will reliably appear in chat
- If something goes wrong, users will know immediately instead of wondering why their message never appeared
- No change to the user experience — this is a behind-the-scenes improvement

## Rollout Plan

This change is backward compatible. Existing app versions will continue to work while mobile teams update to the new approach. No user-facing changes are required.

## Next Steps

1. Backend team implements the new transaction types
2. Mobile teams update apps to use explicit types
3. Monitor for improved reliability
4. Phase 2 (future): Remove the old guessing behavior once all apps have migrated
