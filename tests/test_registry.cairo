use core::num::traits::Zero;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use staked_vote_delegation::interface::{
    IStakedVoteDelegationDispatcher, IStakedVoteDelegationDispatcherTrait,
    IStakedVoteDelegationSafeDispatcher, IStakedVoteDelegationSafeDispatcherTrait, ValidatorConfig,
};
use staked_vote_delegation::registry::StakedVoteDelegation;
use starknet::ContractAddress;

fn addr(v: felt252) -> ContractAddress {
    v.try_into().unwrap()
}
fn MEMBER() -> ContractAddress {
    addr('member')
}
fn STAKER() -> ContractAddress {
    addr('staker')
}
fn OTHER() -> ContractAddress {
    addr('other')
}
fn RECEIVER() -> ContractAddress {
    addr('receiver')
}

fn deploy() -> (IStakedVoteDelegationDispatcher, IStakedVoteDelegationSafeDispatcher) {
    let class = declare("StakedVoteDelegation").unwrap().contract_class();
    let (address, _) = class.deploy(@array![]).unwrap();
    (
        IStakedVoteDelegationDispatcher { contract_address: address },
        IStakedVoteDelegationSafeDispatcher { contract_address: address },
    )
}

fn as_caller(r: IStakedVoteDelegationDispatcher, who: ContractAddress) {
    start_cheat_caller_address(r.contract_address, who);
}

// ---------- defaults (Option B) ----------

#[test]
fn default_vote_goes_to_validator() {
    let (r, _) = deploy();
    assert_eq!(r.get_delegatee(MEMBER()), Zero::zero());
    assert_eq!(r.resolve_pool_member(MEMBER(), STAKER()), STAKER());
    assert_eq!(r.resolve_validator(STAKER()), STAKER());
    assert_eq!(
        r.get_validator_config(STAKER()),
        ValidatorConfig { vote_receiver: STAKER(), accepts_default_delegations: true },
    );
}

// ---------- pool members ----------

#[test]
fn member_keeps_own_vote_by_delegating_to_self() {
    let (r, _) = deploy();
    as_caller(r, MEMBER());
    r.delegate(MEMBER());
    assert_eq!(r.resolve_pool_member(MEMBER(), STAKER()), MEMBER());
}

#[test]
fn member_delegates_to_third_party_across_all_pools() {
    let (r, _) = deploy();
    as_caller(r, MEMBER());
    r.delegate(OTHER());
    assert_eq!(r.get_delegatee(MEMBER()), OTHER());
    assert_eq!(r.resolve_pool_member(MEMBER(), STAKER()), OTHER());
    assert_eq!(r.resolve_pool_member(MEMBER(), addr('staker2')), OTHER());
}

#[test]
fn explicit_choice_beats_validator_decline_and_receiver() {
    let (r, _) = deploy();
    as_caller(r, STAKER());
    r.set_vote_receiver(RECEIVER());
    r.set_accepts_default_delegations(false);
    as_caller(r, MEMBER());
    r.delegate(OTHER());
    assert_eq!(r.resolve_pool_member(MEMBER(), STAKER()), OTHER());
}

#[test]
fn delegation_is_not_transitive() {
    let (r, _) = deploy();
    as_caller(r, OTHER());
    r.delegate(addr('third'));
    as_caller(r, MEMBER());
    r.delegate(OTHER());
    assert_eq!(r.resolve_pool_member(MEMBER(), STAKER()), OTHER());
}

#[test]
fn reset_returns_to_default() {
    let (r, _) = deploy();
    as_caller(r, MEMBER());
    r.delegate(OTHER());
    r.reset_delegation();
    assert_eq!(r.get_delegatee(MEMBER()), Zero::zero());
    assert_eq!(r.resolve_pool_member(MEMBER(), STAKER()), STAKER());
}

#[test]
#[feature("safe_dispatcher")]
fn delegate_rejects_zero_and_unchanged() {
    let (r, safe) = deploy();
    as_caller(r, MEMBER());
    match safe.delegate(Zero::zero()) {
        Result::Ok(_) => panic!("zero accepted"),
        Result::Err(e) => assert_eq!(*e.at(0), StakedVoteDelegation::Errors::ZERO_DELEGATEE),
    }
    r.delegate(OTHER());
    match safe.delegate(OTHER()) {
        Result::Ok(_) => panic!("unchanged accepted"),
        Result::Err(e) => assert_eq!(*e.at(0), StakedVoteDelegation::Errors::UNCHANGED),
    }
}

#[test]
#[feature("safe_dispatcher")]
fn reset_without_delegation_fails() {
    let (r, safe) = deploy();
    as_caller(r, MEMBER());
    match safe.reset_delegation() {
        Result::Ok(_) => panic!("reset accepted"),
        Result::Err(e) => assert_eq!(*e.at(0), StakedVoteDelegation::Errors::NO_DELEGATION),
    }
}

#[test]
fn members_cannot_touch_each_other() {
    let (r, _) = deploy();
    as_caller(r, MEMBER());
    r.delegate(OTHER());
    as_caller(r, OTHER());
    r.delegate(OTHER());
    stop_cheat_caller_address(r.contract_address);
    assert_eq!(r.get_delegatee(MEMBER()), OTHER());
    assert_eq!(r.get_delegatee(OTHER()), OTHER());
}

// ---------- validators ----------

#[test]
fn validator_receiver_gets_default_and_self_stake() {
    let (r, _) = deploy();
    as_caller(r, STAKER());
    r.set_vote_receiver(RECEIVER());
    assert_eq!(r.resolve_pool_member(MEMBER(), STAKER()), RECEIVER());
    assert_eq!(r.resolve_validator(STAKER()), RECEIVER());
    // Zero or self resets to the staker address.
    r.set_vote_receiver(Zero::zero());
    assert_eq!(r.resolve_validator(STAKER()), STAKER());
    r.set_vote_receiver(RECEIVER());
    r.set_vote_receiver(STAKER());
    assert_eq!(r.resolve_validator(STAKER()), STAKER());
}

#[test]
fn validator_decline_returns_votes_to_members() {
    let (r, _) = deploy();
    as_caller(r, STAKER());
    r.set_accepts_default_delegations(false);
    assert_eq!(r.resolve_pool_member(MEMBER(), STAKER()), MEMBER());
    assert!(!r.get_validator_config(STAKER()).accepts_default_delegations);
    // Own self-stake is unaffected by declining.
    assert_eq!(r.resolve_validator(STAKER()), STAKER());
    r.set_accepts_default_delegations(true);
    assert_eq!(r.resolve_pool_member(MEMBER(), STAKER()), STAKER());
}

#[test]
#[feature("safe_dispatcher")]
fn validator_unchanged_writes_fail() {
    let (r, safe) = deploy();
    as_caller(r, STAKER());
    match safe.set_accepts_default_delegations(true) {
        Result::Ok(_) => panic!("unchanged accepted"),
        Result::Err(e) => assert_eq!(*e.at(0), StakedVoteDelegation::Errors::UNCHANGED),
    }
    match safe.set_vote_receiver(STAKER()) {
        Result::Ok(_) => panic!("unchanged accepted"),
        Result::Err(e) => assert_eq!(*e.at(0), StakedVoteDelegation::Errors::UNCHANGED),
    }
}

// ---------- events ----------

#[test]
fn emits_events() {
    let (r, _) = deploy();
    let mut spy = spy_events();
    as_caller(r, MEMBER());
    r.delegate(OTHER());
    r.reset_delegation();
    as_caller(r, STAKER());
    r.set_vote_receiver(RECEIVER());
    r.set_accepts_default_delegations(false);
    let a = r.contract_address;
    spy
        .assert_emitted(
            @array![
                (
                    a,
                    StakedVoteDelegation::Event::DelegateChanged(
                        StakedVoteDelegation::DelegateChanged {
                            delegator: MEMBER(),
                            previous_delegatee: Zero::zero(),
                            new_delegatee: OTHER(),
                        },
                    ),
                ),
                (
                    a,
                    StakedVoteDelegation::Event::DelegateChanged(
                        StakedVoteDelegation::DelegateChanged {
                            delegator: MEMBER(),
                            previous_delegatee: OTHER(),
                            new_delegatee: Zero::zero(),
                        },
                    ),
                ),
                (
                    a,
                    StakedVoteDelegation::Event::VoteReceiverChanged(
                        StakedVoteDelegation::VoteReceiverChanged {
                            staker: STAKER(), previous_receiver: STAKER(), new_receiver: RECEIVER(),
                        },
                    ),
                ),
                (
                    a,
                    StakedVoteDelegation::Event::DefaultDelegationsPreferenceChanged(
                        StakedVoteDelegation::DefaultDelegationsPreferenceChanged {
                            staker: STAKER(), accepts: false,
                        },
                    ),
                ),
            ],
        );
}

// ---------- fuzz ----------

#[test]
#[fuzzer]
fn fuzz_resolution_rules(m: felt252, s: felt252, d: felt252, rcv: felt252, decline: bool) {
    // Keep addresses distinct, non-zero and within range.
    let member = addr((m.into() % 0x1000000_u256 + 1).try_into().unwrap());
    let staker = addr((s.into() % 0x1000000_u256 + 0x2000000).try_into().unwrap());
    let delegatee = addr((d.into() % 0x1000000_u256 + 0x4000000).try_into().unwrap());
    let receiver = addr((rcv.into() % 0x1000000_u256 + 0x6000000).try_into().unwrap());
    let (r, _) = deploy();

    as_caller(r, staker);
    r.set_vote_receiver(receiver);
    if decline {
        r.set_accepts_default_delegations(false);
    }
    let expected_default = if decline {
        member
    } else {
        receiver
    };
    assert_eq!(r.resolve_pool_member(member, staker), expected_default);
    assert_eq!(r.resolve_validator(staker), receiver);

    as_caller(r, member);
    r.delegate(delegatee);
    assert_eq!(r.resolve_pool_member(member, staker), delegatee);
    r.reset_delegation();
    assert_eq!(r.resolve_pool_member(member, staker), expected_default);
}
