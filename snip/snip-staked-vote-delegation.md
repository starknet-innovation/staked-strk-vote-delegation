---
snip: TBD
title: Staked STRK Vote Delegation to Validators (Opt-Out)
description: Staked STRK votes through the pool's validator by default; any delegator can take its vote back or delegate it elsewhere.
author: TBD
discussions-to: TBD
status: Draft
type: Meta
created: 2026-11-10
---

<!-- DRAFT for internal review. Figures, wording and parameters need review before publication. -->

## Simple Summary

Today, staked STRK only counts in Starknet governance if the delegator votes in person, and almost no one does. This SNIP lets the validator a delegator stakes with vote on that delegator's behalf by default. A delegator who disagrees can keep their vote or give it to someone else, at any time, through one call to a registry contract.

## Abstract

This SNIP:

1. Deploys an immutable **Staked Vote Delegation Registry** on Starknet. The registry stores voting preferences only. It holds no funds and has no owner.
2. Changes how the voting power of staked STRK is calculated for Starknet governance votes (Snapshot X) and polls (Snapshot, `starknet.eth`). The voting power of stake held in a delegation pool goes, by default, to that pool's validator.
3. Gives delegators an **opt-out**. A delegator who registers an explicit delegatee in the registry (themselves or anyone else) always gets that choice, whatever the validator does.
4. Gives validators two controls: name a separate voting address, or decline default delegations entirely.

Other voting power sources (vSTRK, L1 STRK, the current delegate whitelist) are unchanged.

## Motivation

Staked STRK is the largest pool of committed, long-term STRK, yet it is almost absent from governance:

| Measure (public on-chain and Snapshot data) | Value |
|---|---|
| Share of staked STRK that voted, average across the last six proposals | 0.5% |
| Share of staked STRK held by delegators (not validators' self-stake) | 91% |
| Delegator addresses that voted on the latest vote (v0.14.3 Updated) | 472 of 61,164 |
| Turnout of staked STRK on the latest vote, today | 0.33% |
| Same vote, if the validators who voted had carried their delegators' stake | 2.89% |
| Post-quantum L1 poll (Oct 2026): today → with validator delegation | 1.76% → 11.30% |

Low turnout causes three problems:

- **Weak legitimacy.** Protocol upgrades pass with support from a tiny share of the stake that secures the network.
- **Easy to capture.** When almost nobody votes, a small organised group can decide the outcome.
- **Lost signal.** Polls show who happened to vote, not what stakers think.

Delegators already trust their validator with their stake: the validator runs the infrastructure, and its performance and conduct decide their rewards. Letting the validator also carry their vote, unless they say otherwise, extends that trust. An opt-in scheme (where a delegator must act to give their vote away) would leave turnout close to today's level, because the delegators who would act are mostly those who already vote. This SNIP therefore uses an opt-out default. Since it changes how existing voting power is assigned, it needs a governance vote.

## Rationale

- **A registry instead of a change to the staking protocol.** The staking and pool contracts are not touched. Governance voting power is already calculated off-chain from staking state (the Snapshot X "Stakers" whitelist and the `strk-staked-balance` Snapshot strategy). Adding one more input to that calculation is the smallest change with the least risk.
- **One delegatee per delegator, across all pools.** This is simple to understand and costs one transaction. A delegator who wants different choices per pool can use separate addresses.
- **No transitive delegation.** A delegatee's own choices do not redirect votes delegated to it. This keeps the result predictable and avoids loops.
- **Validators can decline.** A validator that does not want to vote, or cannot for legal or operational reasons, can return default voting power to its delegators. Pool members then keep their own vote, exactly as today.
- **Separate voting address.** A staker address is often a cold wallet. Validators can name a different address to vote with, without moving stake.
- **Immutable contract.** No owner, upgrade or pause: nobody can change anyone else's choices. If the rules need to change, a new registry is deployed under a new SNIP.
- **Snapshot-time semantics.** Like all other voting power, preferences are read at the proposal's snapshot block. A delegator who wants to vote directly on a proposal must register before its snapshot block.

## Specification

The key words "MUST", "SHOULD" and "MAY" are used as described in RFC 2119.

### Registry interface

```cairo
#[starknet::interface]
pub trait IStakedVoteDelegation<TContractState> {
    // Pool members
    fn delegate(ref self: TContractState, delegatee: ContractAddress);
    fn reset_delegation(ref self: TContractState);
    fn get_delegatee(self: @TContractState, delegator: ContractAddress) -> ContractAddress;
    // Validators (called from the staker address)
    fn set_vote_receiver(ref self: TContractState, receiver: ContractAddress);
    fn set_accepts_default_delegations(ref self: TContractState, accepts: bool);
    fn get_validator_config(self: @TContractState, staker: ContractAddress) -> ValidatorConfig;
    // Resolution
    fn resolve_pool_member(
        self: @TContractState, delegator: ContractAddress, staker: ContractAddress,
    ) -> ContractAddress;
    fn resolve_validator(self: @TContractState, staker: ContractAddress) -> ContractAddress;
}
```

Events: `DelegateChanged(delegator, previous_delegatee, new_delegatee)`, `VoteReceiverChanged(staker, previous_receiver, new_receiver)`, `DefaultDelegationsPreferenceChanged(staker, accepts)`.

The reference implementation is in [`src/registry.cairo`](../src/registry.cairo).

### Resolution rules

For a pool member `M` with stake in a pool operated by staker `V`, `resolve_pool_member(M, V)` returns:

1. `M`'s explicit delegatee, if one is set (this MAY be `M` itself);
2. otherwise `M`, if `V` has declined default delegations;
3. otherwise `V`'s vote receiver (`V` itself if none is set).

For validator `V`'s own stake, `resolve_validator(V)` returns `V`'s vote receiver (`V` if none is set). Declining default delegations does not affect a validator's own stake.

### Voting power calculation

For a proposal with snapshot block `B`, voting power from staked STRK MUST be computed as follows, with all contract state read at block `B`:

1. Enumerate validators and STRK delegation pools from the staking contract (`0x00ca1702e64c81d9a07b86bd2c540188d92a2c73cf5cc0e508d949015e7e84a7`), using the same eligibility rules as the current "Stakers" whitelist.
2. For each validator `V` with self-stake `s_V`: `VP[resolve_validator(V)] += s_V`.
3. For each STRK pool operated by `V`, and each member `M` with balance `b_M > 0`: `VP[resolve_pool_member(M, V)] += b_M`.
4. Each unit of stake is counted once. Pools for other tokens (for example BTC pools) are excluded.

The resulting list MUST be used:

- **Snapshot X (governance votes):** as the Merkle whitelist that replaces the current "Stakers" whitelist strategy.
- **Snapshot `starknet.eth` (polls):** in place of the `strk-staked-balance` strategy, for example as a whitelist or API strategy built from the same list, so that both platforms use identical numbers.

The generator script and its output for each proposal SHOULD be published so anyone can reproduce the list.

### Activation

1. The registry is deployed, and its address published, before the vote on this SNIP.
2. If the SNIP is approved, the opt-out default applies only to proposals whose snapshot block is at least **7 days** after the vote result. During this notice period, delegators can register their choice and validators can decline or name a vote receiver.

### Proposed ballot

> Approve SNIP-TBD: staked STRK votes through the pool's validator by default, with an opt-out for every delegator through the Staked Vote Delegation Registry. — **For / Against / Abstain**

## Implementation

- Contract: `src/registry.cairo`. Cairo 2.18, no dependencies. Tests: `snforge test` (unit and fuzz tests of every resolution rule).
- Voting power generator: an update to the existing staking whitelist generator (TBD, to be published with this SNIP).

## Security Considerations

- **No funds, no admin.** The registry holds no tokens and has no privileged role. Each write changes only the caller's own entry, keyed on `get_caller_address()`.
- **Spam entries.** Anyone can write an entry for their own address. Entries from addresses that hold no stake, or are not stakers, carry no weight in the calculation.
- **Concentration.** The default moves voting power to validators. Large validators, including exchanges and liquid-staking operators, would gain significant weight. A concentration table (top validators by resolved voting power) SHOULD be published with this SNIP before the vote.
- **Contract delegators.** Liquid staking protocols, exchanges and custodians appear as pool members. Unless they call `delegate`, their stake follows the default. Those protocols SHOULD state their intended choice publicly.
- **Validator key compromise.** Control of the staker address already means control of the validator's stake. The registry adds no new key.
- **Timing.** Changes after a proposal's snapshot block have no effect on that proposal. Front-running a snapshot needs staking or delegation changes before it, which are public and subject to the staking contract's exit delays (to be verified).
- **Unused votes.** If a validator does not vote, the voting power delegated to it by default is not used. This is the same result as a delegator who does not vote today.

## History

- 2026-11-10: initial draft.

## Copyright

Copyright and related rights waived via [MIT](../LICENSE).
