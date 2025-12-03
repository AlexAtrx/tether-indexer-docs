## Context

There is a new issue in which I didn't have a lot of context: _docs/tasks/Duplicate_swap_notifications_observed/ticket.md

The issue is that swap notifications get deleted and duplicated.

This is a Slack conversation about the same: _docs/tasks/Duplicate_swap_notifications_observed/conversation.md

This is a truth file that you can quickly to have a glimpse about the app and the notification and the swaps transaction: _docs/___TRUTH.md

This is a diagram showing a basic flow of the processes and the nodes from the front end to the back end, including the back-end indexers: _docs/wdk-indexer-local-diagram.mmd

## Task

1- Go through all the data above and understand the issue. 
2- Go through the entire code base (the repos) and check how the push notifications are populated and how a taken like FCM token can be duplicated in notification. Put into account that it's intermittent. 
3- Catch the potential culprit and explain it to me. 
4- Write your finding in an analysis file in the same folder: _docs/tasks/Duplicate_swap_notifications_observed
(Don't write a code for now).
