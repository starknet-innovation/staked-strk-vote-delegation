# Staked STRK Vote Delegation

A draft proposal, with its contract, to let staked STRK take part in Starknet governance. By default, the validator a delegator stakes with votes for them (opt-out). Any delegator can take their vote back or delegate it elsewhere.

> **Status: draft for internal review.** Not audited, not deployed.

## Contents

| Path | What it is |
|---|---|
| [`snip/snip-staked-vote-delegation.md`](snip/snip-staked-vote-delegation.md) | SNIP draft: motivation, rules, voting power calculation, activation, ballot |
| [`src/interface.cairo`](src/interface.cairo) | `IStakedVoteDelegation` interface |
| [`src/registry.cairo`](src/registry.cairo) | Reference registry contract (immutable, no owner, holds no funds) |
| [`tests/test_registry.cairo`](tests/test_registry.cairo) | snforge unit and fuzz tests |
| [`audits/`](audits/) | Automated security reviews (AI, not a professional audit) |

## How it works

| Who | Call | Effect |
|---|---|---|
| Delegator | nothing | Vote goes to the pool's validator (or to its vote receiver) |
| Delegator | `delegate(self)` | Keeps their own vote |
| Delegator | `delegate(x)` | Vote goes to `x` as given, in every pool (no need to delegate to your own validator: that is the default) |
| Delegator | `reset_delegation()` | Back to the default |
| Validator | `set_vote_receiver(x)` | `x` votes with the validator's own stake and default delegations |
| Validator | `set_accepts_default_delegations(false)` | Delegators who made no choice keep their own vote |

Voting power is still calculated off-chain at each proposal's snapshot block, from the staking contract plus this registry. See the SNIP for the rules.

## Build and test

Requires Scarb 2.18 and Starknet Foundry 0.60.

```sh
scarb build
snforge test
```

## Licence

MIT
