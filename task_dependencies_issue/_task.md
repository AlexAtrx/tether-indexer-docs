We have this urgent important issue:

## Slack chat

==============
fyi another npm attack: https://helixguard.ai/blog/malicious-sha1hulud-2025-11-24, please double check packages, it seems along affected is ethereum-ens

The attack page: 
https://helixguard.ai/blog/malicious-sha1hulud-2025-11-24
-------

This is why we should always pin dependencies by the way, not sure if we already have that as best practice (and disable pre/post install scripts).

----

These are the impacted libraries:

ens packages
ethereum-ens
crypto-addr-codec
uniswap-router-sdk
valuedex-sdk
coinmarketcap-api
luno-api
soneium-acs
evm-checkcode-cli
gate-evm-check-code2
gate-evm-tools-test
create-hardhat3-app
test-hardhat-app
test-foundry-app
@accordproject/concerto-analysis
@accordproject/concerto-linter
@accordproject/concerto-linter-default-ruleset
@accordproject/concerto-metamodel
@accordproject/markdown-it-cicero
@accordproject/template-engine
@ifelsedeveloper/protocol-contracts-svm-idl

----

Can you confirm if we are using any of these libraries in the project?

==============

## Your task

- Check the web page rewiring all its contents if you can. If you can't stop and tell until I provide its contents.
- Read the provided list of dependencies in Slack chat.
- Go thought all the repos and code in this project and tell me which repo uses any of the decencies in the Slack-shared list or any dependencies/effect that can be concluded from the web page. 
