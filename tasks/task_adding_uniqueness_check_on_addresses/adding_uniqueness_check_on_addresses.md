- Context:
Must read ‘./_docs/___TRUTH.md’ for context.

- In short:
"
Wallet address uniqueness: enforce hard validation at org‑level on wallet creation to prevent address‑collision attacks; change warning to error.
"

- Details - conversation between devs:
"
So essentially the attacker could overwrite the existing address‑to‑wallet mapping at the org level, right? We might need a uniqueness constraint or signature check to ensure only the original wallet creator can bind those addresses.
"
"
Yes, we can enforce that at wallet creation by adding a uniqueness check on addresses within the org scope before persisting the wallet record.
"
"
So basically the lookup gets overwritten, and future queries return wallet B instead of wallet A, right? That’s the core issue we need to prevent with the uniqueness check.
"
"
Currently the API returns a warning if things don't match.
"
"
Right, in that case we should switch it from a warning to a hard validation error so the wallet creation fails if any address already exists in the org mapping.
"

- The ticket:
Read it in file: _docs/_tickets/Ensure-uniqueness_of_addresses_in_wallet_creation_or_update.md

- Where is the focus?
This project has generic libraries (open source) and application repos using the libraries. This bug must be handled at the application level (unless you think otherwise). The application is Rumble wallet; thus focus on Rumble repos.

- The task:
Find the APIs responsible for the current security bug. Find the warning one of the devs is talking about. This warning must be replaced with... etc as you know. 

- Note:
If there is anything not clear to you, ask and stop until I answer. 
Think deeply about this. 
Take all the time you need. 
Stick to the existing conventions. Don't over-claver it. 
Do NOT commit any code. 
