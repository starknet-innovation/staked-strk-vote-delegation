# Working agreement

This applies to everyone changing this repository, people and coding agents alike. Read
`README.md` and the SNIP draft in `snip/` first: the contract in `src/` is the reference
implementation of that draft, so the two must not drift apart.

## Hygiene level

This repository holds a **Tier 1 baseline**: pinned tools, a committed lockfile, tests kept apart
from source, fatal warnings, and the same gates locally and in CI. It makes no claim beyond that.
In particular, the reviews in `audits/` are automated and are not a professional audit.

## Gates

Tool versions are pinned in `.tool-versions`. Use exactly those versions; a missing or different
tool is a failure, not a reason to skip a step.

```sh
scarb fmt --check
scarb lint --test --deny-warnings
scarb build
snforge test
```

All four must pass before a change is handed over. Compiler warnings are errors
(`allow-warnings = false` in `Scarb.toml`). Never relax a gate, delete a test or loosen an
assertion to get a green result. If a gate is wrong, say so and change it in its own reviewed
commit.

## Layout

- `src/` holds production Cairo only. No `#[test]` or `#[cfg(test)]` code lives there.
- `tests/acceptance/` holds the black-box suites that exercise the deployed contract.
- `tests/lib.cairo` only declares the suites. snforge silently ignores a nested suite that is
  not declared there, so add the `mod` line whenever you add a file.
- Add `tests/unit/`, `tests/integration/`, `tests/fixtures/` or `tests/support/` when needed.
  Nothing else sits directly under `tests/`.
- Keep one current implementation. Earlier versions belong in Git history, not in `v1`/`old` trees.

## How to work

1. Start from an issue that states the behaviour wanted and how it will be tested.
2. Write or change the acceptance test first, then the contract.
3. Keep each branch to one small change and open a pull request. Do not push to `main`.
4. A change to the interface, events, error messages or storage layout is a change to the SNIP.
   Update the draft in the same pull request and call it out in the description.
5. In the handover, list the commands you actually ran and their results, and anything you could
   not run. Do not report a check as passed if it did not run.

Never commit secrets, private keys or account files.
