# Description

After authentication, the full wallet balance takes approximately **1 minute** to load completely.
Instead of loading all balances together, wallet assets update progressively **piece by piece**, causing multiple intermediate balance states before final synchronization is completed.

During this time:
- Main balance remains in loading state
- Individual asset balances update gradually
- Different balances appear at different times

## Steps to Reproduce
1. Open the app
2. Complete authentication
3. Navigate to the Home / Balance screen
4. Observe balance loading behavior

## Expected Result
- Full balance should load within a reasonable time
- Wallet balances should load consistently together
- Users should not see prolonged partial balance states

## Actual Result
- Full balance loading takes around ~1 minute
- Multiple intermediate balance states appear before final load completes

**Device:** iPhone 14 pro IOS 26.4.2
**Version:** v2.2.0 (596)
