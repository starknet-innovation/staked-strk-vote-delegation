# Security Review — staked-strk-vote-delegation

> Automated AI review (cairo-auditor v0.2.2, deep mode: 4 vector-scan agents + 1 adversarial agent) of commit `709577e`. Not a professional audit.
>
> **Resolution of finding 1:** kept as designed (explicit delegatees are used as given, no transitive routing). The SNIP and README now tell delegators they don't need to delegate to their own validator, and say interfaces should warn them if they try.

## Signal Summary

| Critical | High | Medium | Low | Total |
|----------|------|--------|-----|-------|
| 0 | 0 | 0 | 1 | 1 |

---

## Scope

|                                  |                                                        |
| -------------------------------- | ------------------------------------------------------ |
| **Mode**                         | deep |
| **Files reviewed**               | `src/interface.cairo` · `src/lib.cairo` · `src/registry.cairo` |
| **Total in-scope lines**         | 237 |
| **Confidence threshold (0-100)** | 75 |
| **Proven-only mode**             | off |
| **Preflight findings**           | 4 deterministic hits |
| **Generated**                    | 2026-11-10T18:17:55+00:00 |

`Execution Integrity: FULL`

---

## Execution Trace

| Stage | Model | Evidence | Status |
|---|---|---|---|
| Scope discovery | n/a | `cairo-audit-files.txt` (3 files) | OK |
| Threat intel enrichment (optional) | n/a | `cairo-audit-threat-intel.md` | SKIPPED: small self-contained contract, no external integrations |
| Agent 1 vector scan | unknown | `cairo-audit-agent-1-bundle.md` (760 lines) | OK |
| Agent 2 vector scan | unknown | `cairo-audit-agent-2-bundle.md` (760 lines) | OK |
| Agent 3 vector scan | unknown | `cairo-audit-agent-3-bundle.md` (760 lines) | OK |
| Agent 4 vector scan | unknown | `cairo-audit-agent-4-bundle.md` (768 lines) | OK |
| Agent 5 adversarial (deep only) | unknown | `cairo-audit-agent-5-findings.json` (1 findings) | OK |

---

## Findings

[P3] **1. Explicit delegation to a validator's staker address skips that validator's vote_receiver and decline settings**

`Class: GOVERNANCE_VOTING_POWER_MISROUTING` · `src/registry.cairo:141` · Confidence: 50 · Severity: Low · `[CODE-TRACE] [ADVERSARIAL]`

**Description**
Validator controls (vote_receiver, decline) only apply on the default path. A member who explicitly calls delegate(V_staker) sends voting power to the staker address regardless of the validator's receiver or decline. Consistent with the SNIP's non-transitive rule, but a natural user action that strands votes on a cold wallet or overrides a decline. No funds or control gained.

**Guard Analysis**
No guard by design: step 1 returns early; set_vote_receiver and set_accepts_default_delegations only affect steps 2-3.

---

## Dropped Candidates

| Candidate | Class | Drop Reason |
|-----------|-------|-------------|
| `NO_ACCESS_CONTROL_MUTATION preflight hit: delegate()` | `ungated-privileged-mutation (V6/V8/V90)` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: reset_delegation()` | `ungated-privileged-mutation (V6/V8/V90)` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: set_vote_receiver()` | `ungated-privileged-mutation (V6/V8/V90)` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: set_accepts_default_delegations()` | `ungated-privileged-mutation (V6/V8/V90)` | `false_positive` |
| `Non-staker caller writing vote_receiver/declines_defaults for arbitrary staker slot` | `caller-alias / auth bypass (V7/V87)` | `false_positive` |
| `Same address acting as validator and pool member causing cross-role voting-power confusion` | `authority drift (V81)` | `false_positive` |
| `Missing owner/upgrade/pause, no recovery path` | `irrevocable role / missing upgrade` | `false_positive` |
| `State mutation before check (V132)` | `auth-after-mutation` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: delegate()` | `missing-access-control` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: reset_delegation()` | `missing-access-control` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: set_vote_receiver()` | `missing-access-control` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: set_accepts_default_delegations()` | `missing-access-control` | `false_positive` |
| `Non-staker caller registers vote_receiver or declines_defaults to hijack or inflate voting power` | `voting-power-assignment` | `false_positive` |
| `Validator changes vote_receiver or toggles accepts_default_delegations just before the snapshot to redirect default-delegated pool voting power` | `voting-power-assignment` | `insufficient_evidence` |
| `Transitive or chained delegation, or delegation loops, inflating voting power` | `voting-power-assignment` | `false_positive` |
| `Zero-address or self-delegation edge cases causing lost or duplicated voting power` | `input-validation` | `false_positive` |
| `Caller-supplied staker argument in resolve_pool_member / resolve_validator (view functions) being spoofed` | `input-validation` | `false_positive` |
| `Reentrancy, external-call, messaging and L1/L2 vectors` | `external-calls-reentrancy-messaging` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: delegate()` | `missing-access-control` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: reset_delegation()` | `missing-access-control` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: set_vote_receiver()` | `missing-access-control` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: set_accepts_default_delegations()` | `missing-access-control` | `false_positive` |
| `Validator redirects default-delegated pool voting power by changing vote_receiver or accepts_default right before a snapshot` | `economic-logic / voting-power assignment` | `false_positive` |
| `Non-staker address calls set_vote_receiver / set_accepts_default_delegations to pollute registry` | `voting-power spoofing` | `false_positive` |
| `Voting power double-count or inconsistency when a staker address is also a pool member (resolve_validator and resolve_pool_member use independent maps)` | `accounting-logic` | `insufficient_evidence` |
| `Single delegatee per delegator applies to all pools (no per-staker granularity), with explicit choice overriding validator decline` | `economic-logic` | `false_positive` |
| `Arithmetic, fee, rounding, oracle and vault vectors V41-V60, V101-V110, V145-V156` | `math/pricing` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: delegate()` | `NO_ACCESS_CONTROL_MUTATION` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: reset_delegation()` | `NO_ACCESS_CONTROL_MUTATION` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: set_vote_receiver()` | `NO_ACCESS_CONTROL_MUTATION` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION preflight hit: set_accepts_default_delegations()` | `NO_ACCESS_CONTROL_MUTATION` | `false_positive` |
| `V62 Map-zero default confusion` | `Map-zero default confusion` | `false_positive` |
| `V72 Over-broad registry persistence / spam writes by arbitrary callers` | `Over-broad registry persistence` | `false_positive` |
| `V74/V112 Storage key collision across the three maps` | `Storage key composition collision` | `false_positive` |
| `Validator sets vote_receiver to an unusable address so default-delegated pool members' voting power is lost` | `Voting power misassignment` | `below_confidence_threshold` |
| `Self-delegation vs reset ambiguity` | `Map-zero default confusion` | `false_positive` |
| `NO_ACCESS_CONTROL_MUTATION on the four writers (preflight hints)` | `ACCESS_CONTROL` | `false_positive` |
| `Third party forces a contract pool member with an arbitrary-call path to call delegate` | `CONTRACT_CALLER_CONFUSED_DEPUTY` | `insufficient_evidence` |
| `Contract pool members with no call path can never opt out` | `GOVERNANCE_DESIGN` | `insufficient_evidence` |
| `Validator switches vote_receiver or decline in the snapshot block` | `TIMING_FRONT_RUN` | `false_positive` |
| `Validator calls delegate() expecting to redirect its self-stake; ignored by resolve_validator` | `ROLE_NAMESPACE_CONFUSION` | `below_confidence_threshold` |
| `Zero or out-of-range ContractAddress as delegatee or receiver` | `FELT_ADDRESS_SEMANTICS` | `false_positive` |
| `Mismatch between contract resolution and SNIP rules` | `SPEC_MISMATCH` | `false_positive` |
| `Delegation loops or transitive amplification` | `GOVERNANCE_VOTING_POWER_MANIPULATION` | `false_positive` |
| `Spam entries from non-stakers` | `GRIEFING` | `false_positive` |

---

## Findings Index

| # | Priority | Confidence | Severity | Evidence | Title |
|---|----------|------------|----------|----------|-------|
|   |          |            |          |  | **Below Confidence Threshold** |
| 1 | P3 | 50 | Low | `[CODE-TRACE] [ADVERSARIAL]` | Explicit delegation to a validator's staker address skips that validator's vote_receiver and decline settings |

---

> **Disclaimer.** This review was performed by an automated AI tool. Automated analysis catches pattern-based vulnerabilities but cannot detect specification bugs, economic exploits, cross-protocol interactions, or game-theoretic attacks. This report does not guarantee the absence of vulnerabilities. Use it as a pre-commit and pre-deployment gate, not as a substitute for professional security audits, formal verification, or manual code review.
