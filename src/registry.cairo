/// Staked STRK vote delegation registry.
///
/// Immutable by design: no owner, no upgrade, no pause. Every write only
/// changes the caller's own entry, so no function needs access control
/// beyond `get_caller_address()`.
#[starknet::contract]
pub mod StakedVoteDelegation {
    use core::num::traits::Zero;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use crate::interface::{IStakedVoteDelegation, ValidatorConfig};

    pub mod Errors {
        pub const ZERO_CALLER: felt252 = 'SVD: zero caller';
        pub const ZERO_DELEGATEE: felt252 = 'SVD: zero delegatee';
        pub const NO_DELEGATION: felt252 = 'SVD: no delegation set';
        pub const UNCHANGED: felt252 = 'SVD: value unchanged';
    }

    #[storage]
    struct Storage {
        /// delegator => explicit delegatee (zero = default applies).
        delegatee: Map<ContractAddress, ContractAddress>,
        /// staker => vote receiver (zero = staker itself).
        vote_receiver: Map<ContractAddress, ContractAddress>,
        /// staker => declined default delegations. Stored inverted so the
        /// zero value matches the Option B default (accepts).
        declines_defaults: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        DelegateChanged: DelegateChanged,
        VoteReceiverChanged: VoteReceiverChanged,
        DefaultDelegationsPreferenceChanged: DefaultDelegationsPreferenceChanged,
    }

    /// `new_delegatee` is zero when the delegator returns to the default.
    #[derive(Drop, starknet::Event, PartialEq, Debug)]
    pub struct DelegateChanged {
        #[key]
        pub delegator: ContractAddress,
        pub previous_delegatee: ContractAddress,
        pub new_delegatee: ContractAddress,
    }

    /// Receivers are reported as effective values (staker address when unset).
    #[derive(Drop, starknet::Event, PartialEq, Debug)]
    pub struct VoteReceiverChanged {
        #[key]
        pub staker: ContractAddress,
        pub previous_receiver: ContractAddress,
        pub new_receiver: ContractAddress,
    }

    #[derive(Drop, starknet::Event, PartialEq, Debug)]
    pub struct DefaultDelegationsPreferenceChanged {
        #[key]
        pub staker: ContractAddress,
        pub accepts: bool,
    }

    #[abi(embed_v0)]
    impl StakedVoteDelegationImpl of IStakedVoteDelegation<ContractState> {
        /// Public: writes only the caller's own entry.
        fn delegate(ref self: ContractState, delegatee: ContractAddress) {
            let delegator = caller();
            assert(!delegatee.is_zero(), Errors::ZERO_DELEGATEE);
            let previous = self.delegatee.read(delegator);
            assert(previous != delegatee, Errors::UNCHANGED);
            self.delegatee.write(delegator, delegatee);
            self
                .emit(
                    DelegateChanged {
                        delegator, previous_delegatee: previous, new_delegatee: delegatee,
                    },
                );
        }

        /// Public: writes only the caller's own entry.
        fn reset_delegation(ref self: ContractState) {
            let delegator = caller();
            let previous = self.delegatee.read(delegator);
            assert(!previous.is_zero(), Errors::NO_DELEGATION);
            self.delegatee.write(delegator, Zero::zero());
            self
                .emit(
                    DelegateChanged {
                        delegator, previous_delegatee: previous, new_delegatee: Zero::zero(),
                    },
                );
        }

        fn get_delegatee(self: @ContractState, delegator: ContractAddress) -> ContractAddress {
            self.delegatee.read(delegator)
        }

        /// Public: writes only the caller's own entry. The entry has effect
        /// only if the caller is a staker address in the staking contract;
        /// for any other caller it is ignored by the generators.
        fn set_vote_receiver(ref self: ContractState, receiver: ContractAddress) {
            let staker = caller();
            let previous = self.effective_receiver(staker);
            // Store zero when the receiver is the staker itself.
            let stored = if receiver == staker {
                Zero::zero()
            } else {
                receiver
            };
            let new_receiver = if stored.is_zero() {
                staker
            } else {
                stored
            };
            assert(previous != new_receiver, Errors::UNCHANGED);
            self.vote_receiver.write(staker, stored);
            self.emit(VoteReceiverChanged { staker, previous_receiver: previous, new_receiver });
        }

        /// Public: writes only the caller's own entry (see `set_vote_receiver`).
        fn set_accepts_default_delegations(ref self: ContractState, accepts: bool) {
            let staker = caller();
            let declines = !accepts;
            assert(self.declines_defaults.read(staker) != declines, Errors::UNCHANGED);
            self.declines_defaults.write(staker, declines);
            self.emit(DefaultDelegationsPreferenceChanged { staker, accepts });
        }

        fn get_validator_config(self: @ContractState, staker: ContractAddress) -> ValidatorConfig {
            ValidatorConfig {
                vote_receiver: self.effective_receiver(staker),
                accepts_default_delegations: !self.declines_defaults.read(staker),
            }
        }

        fn resolve_pool_member(
            self: @ContractState, delegator: ContractAddress, staker: ContractAddress,
        ) -> ContractAddress {
            // 1. An explicit choice always wins (one hop, never transitive).
            let explicit = self.delegatee.read(delegator);
            if !explicit.is_zero() {
                return explicit;
            }
            // 2. Validator declined defaults: the member keeps the vote.
            if self.declines_defaults.read(staker) {
                return delegator;
            }
            // 3. Default: the validator's vote receiver.
            self.effective_receiver(staker)
        }

        fn resolve_validator(self: @ContractState, staker: ContractAddress) -> ContractAddress {
            self.effective_receiver(staker)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn effective_receiver(self: @ContractState, staker: ContractAddress) -> ContractAddress {
            let stored = self.vote_receiver.read(staker);
            if stored.is_zero() {
                staker
            } else {
                stored
            }
        }
    }

    fn caller() -> ContractAddress {
        let c = get_caller_address();
        assert(!c.is_zero(), Errors::ZERO_CALLER);
        c
    }
}
