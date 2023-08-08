# TEZOS DAO

Tezos D.A.O. with Decentralized Identity system and Anti-Whale measures.

## Intro

This example DAO allows FA2 token holders to vote on proposals, which trigger
on-chain changes when accepted.

It is using token based quorum voting, requiring a given threshold of
participating tokens for a proposal to pass.

The contract code uses LIGO [modules](https://ligolang.org/docs/language-basics/modules/),
and the [@ligo-fa2 package](https://packages.ligolang.org/package/@ligo/fa).
Learn about LIGO packages [here](https://ligolang.org/docs/advanced/package-management).

The used `FA2` token is expected to extend the standard with an on-chain view
`total_supply` returning the total supply of tokens, used as base for the
participation computation, see [example `FA2` in the test directory](./test/bootstrap/single_asset.mligo).

## Docs

- [Specification](./docs/specification.md)
- [Lambdas](./docs/lambdas.md)
- [Tests](./docs/tests.md)

## Usage

This repository requires Docker `24.0.5 or later` to be installed.

1. Run `make install` to install dependencies
2. Run `make` to see available commands

If you do not wish to user Docker, you can modify the `LIGO` variable in the `Makefile`
to point to a local LIGO binary.
You can get a LIGO binary for `v0.70.1` [here](https://gitlab.com/ligolang/ligo/-/releases/0.70.1).

## Resources

- <https://github.com/tezos-commons/baseDAO>
- <https://github.com/Hover-Labs/murmuration>
- <https://forum.salsadao.xyz/t/governance-principles-what-should-it-do-how-should-it-work-etc/52>
- <https://medium.com/@tstyle11/time-locks-5b644651e4a3>
- <https://github.com/kickflowio/flow-dao>
- <https://rekt.news>
- <https://soliditydeveloper.com/comp-governance>
- <https://medium.com/daostack/voting-options-in-daos-b86e5c69a3e3>
- <https://xord.com/research/curve-dao-a-brief-outlook-to-the-mechanism-of-dao/>
- <https://finance.yahoo.com/news/defi-projects-embrace-vote-locking-161806673.html?guccounter=1>
- <https://medium.com/block-science/dao-vulnerabilities-a-map-of-lido-governance-risks-opportunities-92bc6384ff68>
- <https://policyreview.info/glossary/permissionlessness>
- <https://medium.com/block-science/aligning-the-concept-of-decentralized-autonomous-organization-to-precedents-in-cybernetics-51344d1c1411>
- <https://sarahlu.notion.site/sarahlu/just-another-web3-reading-list-f917a3b6a81e4a9a8f947a236c0e141a>
    
## Anti-Whale System

### Explanation

The D.A.O. uses an anti-whale voting system, working as follows :
- Each user has a token score. For each vote, the base token score is initialised in the configuration at `s = 1 000 000` for smoothing purpose, and this value is added to the user locked tokens for this vote `x`, resulting in a final token score `X = s + x`.
- Each user has a reputation score. The base reputation score is initialised in the configuration at `b = 10` for smoothing purpose.  At each succesfull vote, each user is rewarded one cumulative reputation point in a counter `y`, resulting in a final reputation score `Y = b + y`.
- Each user has a fidelity score. The base fidelity score is initialised in the configuration at `t = 31 536 000` for smoothing purpose. At each lock, we note the timestamp, and calculate at each vote the total lock time `z` in seconds. Note that locking and releasing multiple times cumulate your lock time.  resulting in a final fidelity score `Z = t + z`.

The final voting weight power `V` for each user is `V = X * Y * Z`

### Technical mecanism

We have an (address, score) big_map in the storage:  

score type = {  
&nbsp; &nbsp; reputation: nat;  
&nbsp; &nbsp; fidelity: nat;  
&nbsp; &nbsp; last_updated_timestamp: timestamp;  
}  

1. When a user `lock` : if we had a `lock` in progress, we add the seconds between `last_updated_timestamp` and `now` to their `fidelity` score. If not and the user never locked any tokens, we create an entry in the `big_map` with `reputation` and `fidelity` at `0n`. In any cases, we overwrite the `last_updated_timestamp` to `now`.

2. When there happen an `end_vote` : we iterate over the `map` of all the entries of those who voted and we add one point (`+1n`) reputation to the `reputation` score and we add the seconds between `last_updated_timestamp` and `now` to their `fidelity` score. We overwrite the `last_updated_timestamp` to `now`. {The vote is then casted with the updated weights}

3. When a user `release`: we add the seconds between `last_updated_timestamp` and `now` to their `fidelity` score. We overwrite the `last_updated_timestamp` to `now`.


## Next Steps
- Enchancements :
    - [ ] Had a minimum start_delay
- D.I.D. Integration :
    - Members of the D.A.O. should have a valid D.I.D. (maybe through [TzProfiles](https://tzprofiles.com/) ?)
        - [ ] Add a Whitelist to the contract to validate users and their D.I.D.
        - [ ] Non-members can request access to the D.A.O. by attaching their TzProfile as a parameter
        - [ ] Members can validate the D.I.D. requests per user


