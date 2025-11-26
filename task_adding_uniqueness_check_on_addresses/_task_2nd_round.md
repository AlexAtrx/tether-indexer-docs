## Context

- This task was done and PR is raised in repo 'wdk-ork-wrk'.
- The PR: https://github.com/tetherto/wdk-ork-wrk/pull/45/files

## Updates

We have these new comments:
-----------
Key dev:
"
So, a couple of things:

The migration file should be created in the rumble-ork-wrk project, since it'll be used from there.
In the migration, we are normalizing the addresses for existing wallets at the ork-level. But for data-shards, which store the wallets, they'll continue to have non-normalized addresses in the wallets. Therefore, I think it makes sense to update the getWalletByAddress RPC call as well to normalize the address before fetching from the database. Wdyt?
"

Extra dev:
"
Can we run similar migration at shard-level? for existing saved wallets, we can also notify this information to frontend team for other rpc calls to make sure addresses are case sensitive to blockchain
"

Key dev:
"
Yes, I think it makes sense to run the migration on the data-shard level as well. Please include that as well here. We should write migration for mongo as well as hyperdb.
"
-----------

## Task
1- Read the task and your fix report. This is all the data in _docs/task_adding_uniqueness_check_on_addresses.
2- Check the PR changes (if you can't access it, stop and help me help you).
3- Address the updates shared above and think about their meaning very well. 
4- Explain in short, based on all your understanding, what needs to be done and if it makes sense. 
