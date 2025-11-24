This folder includes context data of old task you worked on, and you even up finding out that the problem is in Hyperswam, not MongoDB issue. 

You already did find in your analysis in the file DIAGNOSIS_REPORT.md the problem is 'Hyperswarm RPC pool timeout race condition' with 100% assurance. Still, I'm now required to run the relevant services to replicate the error/problem locally so to confirm to the team with 100%.

I wrote a message for the team in Slack channel communicating your findings, and the team lead said:
"
From your message, if no RPC calls have been made to a specific indexer for 5 minutes , the pool starts destruction (timeout), we should be able to configure this to something more frequent, like every 5 seconds?
"

You already wrote a fix for this issue but I'm now stating it in another folder outside this project. This is to run things locally 1st with the existing code.

Before you go about this task, it's probably helloing to read ‘./_docs/___TRUTH.md’ for context. Optionally you can read all what's in ‘./_docs’ to get a good grasp of this app.

Now, I want you to give me, step by step, what should I do to reproduce the issue locally. 