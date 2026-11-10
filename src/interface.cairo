use starknet::ContractAddress;

/// Preferences a validator (identified by its staker address) has registered.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct ValidatorConfig {
    /// Address that receives the validator's governance voting power.
    /// Equal to the staker address when no receiver has been set.
    pub vote_receiver: ContractAddress,
    /// Whether the validator accepts the voting power of pool members who
    /// have not chosen a delegatee. `true` unless the validator declined.
    pub accepts_default_delegations: bool,
}

/// Registry recording how staked STRK voting power is delegated.
///
/// The registry stores preferences only. It holds no funds and does not read
/// balances. Off-chain voting power generators (Snapshot X whitelist, Snapshot
/// strategy) combine these preferences with staking contract state at the
/// proposal's snapshot block, following the rules in the SNIP.
///
/// Default (Option B, opt-out): a pool member who has registered nothing gives
/// the voting power of the stake in a pool to that pool's validator.
#[starknet::interface]
pub trait IStakedVoteDelegation<TContractState> {
    // ---- Pool members ----

    /// Sets the caller's delegatee for all of the caller's pool stake.
    /// Passing the caller's own address keeps the voting power with the caller.
    fn delegate(ref self: TContractState, delegatee: ContractAddress);

    /// Removes the caller's explicit choice, returning to the default
    /// (voting power goes to the validator of each pool).
    fn reset_delegation(ref self: TContractState);

    /// Explicit delegatee of `delegator`, or the zero address if none is set.
    fn get_delegatee(self: @TContractState, delegator: ContractAddress) -> ContractAddress;

    // ---- Validators (called from the staker address) ----

    /// Sets the address that votes with the caller's voting power.
    /// Passing the zero address resets it to the staker address.
    fn set_vote_receiver(ref self: TContractState, receiver: ContractAddress);

    /// Declines (`false`) or accepts again (`true`) the default delegations
    /// of pool members who have made no choice.
    fn set_accepts_default_delegations(ref self: TContractState, accepts: bool);

    fn get_validator_config(self: @TContractState, staker: ContractAddress) -> ValidatorConfig;

    // ---- Resolution (normative rules, see SNIP) ----

    /// Address that votes with stake `delegator` holds in a pool operated by
    /// `staker`.
    fn resolve_pool_member(
        self: @TContractState, delegator: ContractAddress, staker: ContractAddress,
    ) -> ContractAddress;

    /// Address that votes with the self-stake of validator `staker`.
    fn resolve_validator(self: @TContractState, staker: ContractAddress) -> ContractAddress;
}
