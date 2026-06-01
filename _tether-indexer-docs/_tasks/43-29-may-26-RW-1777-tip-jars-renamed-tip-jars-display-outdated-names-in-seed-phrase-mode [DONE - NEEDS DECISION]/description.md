# Description

In **Seed Phrase mode**, renamed Tip Jars continue displaying their previous/default names instead of the updated renamed values.

The issue appears in the balance/tip jar selection list, where the old cached name is shown even after the Tip Jar has already been renamed successfully.

## Steps to Reproduce

1. Open app in **Seed Phrase mode**
2. Rename a Tip Jar
3. Navigate to the balance/tip jar selection view
4. Observe Tip Jar name

## Expected Result

- Renamed Tip Jar should display the updated name consistently across the app

## Actual Result

- Previous/default Tip Jar name is displayed instead of renamed value
- Updated name is not reflected correctly in the list

**Device:** Pixel 7 v16
**Version:** v2.2.0 (686)
