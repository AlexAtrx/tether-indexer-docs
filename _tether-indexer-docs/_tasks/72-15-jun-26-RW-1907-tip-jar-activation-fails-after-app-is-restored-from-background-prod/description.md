Description 
After bringing the app back from the background, Tip Jar activation fails and returns an error.
 
The issue persists during the current session and is resolved only after restarting the app. After restart, Tip Jar activation works correctly.
 Steps to Reproduce 
    Open the app
    Send the app to background
    Reopen the app from background
    Navigate to Tip Jars
    Try to activate a Tip Jar

 Expected Result 
    Tip Jar should activate successfully after app is restored from background
    No error should appear
    App state should recover correctly without restart

 Actual Result 
    Tip Jar activation returns an error after app is restored from background
    Activation does not complete
    App restart resolves the issue

Version: v2.4 (207)
Device: iPhone 14 Pro IOS 27 - Prod
