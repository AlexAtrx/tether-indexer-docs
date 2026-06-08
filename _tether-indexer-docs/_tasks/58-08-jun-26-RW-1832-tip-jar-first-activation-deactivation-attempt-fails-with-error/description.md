# Description

Tip Jar activation/deactivation does not work reliably on the first attempt.

When the user toggles a Tip Jar, the operation may fail and display an error
message (e.g. "Could not activate Tip Jar"). Retrying the same action
immediately afterwards succeeds.

This creates the impression that the action failed, even though it can be
completed on the second attempt.

**Credentials:** gwallet126 / 123qweASD! / eternal feature bus rich select penalty wrist finish wonder divorce inmate certain

## Steps to Reproduce

1. Try to activate or deactivate a Tip Jar
2. Observe the result of the first attempt
3. Retry the same action

## Expected Result

- Tip Jar should activate/deactivate successfully on the first attempt
- No error message should appear when the operation is successful on the backend

## Actual Result

- First activation/deactivation attempt returns an error
- Retrying the action succeeds
- User receives misleading failure feedback

**Device:** iPhone 14 Pro iOS 26.5 / Pixel 7 v16
**Version:** v2.3 (631) / (717)
