# Contributing

Feedback on the SNIP draft and fixes to the reference contract are both welcome.

## Discussing the design

Open an issue for questions about the delegation rules, the opt-out default or the voting power
calculation. Say which section of `snip/snip-staked-vote-delegation.md` you are commenting on.

## Changing code

1. Install the tool versions listed in `.tool-versions` (Scarb and Starknet Foundry). Both
   [asdf](https://asdf-vm.com) and the official installers can read that file.
2. Open an issue describing the behaviour you want and how it should be tested.
3. Create a branch, add or change a test under `tests/acceptance/`, then change `src/`.
   Declare any new test file in `tests/lib.cairo`, or it will not run.
4. Run the checks:

   ```sh
   ./scripts/check.sh
   ```

   It runs `scarb fmt --check`, `scarb lint --test --deny-warnings`, `scarb build` and
   `snforge test`, and fails if no test ran.

5. Open a pull request. CI runs the same script. A code owner reviews before merge.

If your change touches the interface, events, errors or storage, update the SNIP draft in the
same pull request.

## Pre-commit hook

Turn it on once per clone. It runs `./scripts/check.sh --fast` (everything except the tests)
before each commit:

```sh
git config core.hooksPath .githooks
```

CI is the authority either way.

## Security

Please do not open a public issue for a vulnerability. Use GitHub's private vulnerability
reporting on this repository.

## Licence

Contributions are accepted under the MIT licence in `LICENSE`.

See `AGENTS.md` for the full working agreement, which also applies to coding agents.
