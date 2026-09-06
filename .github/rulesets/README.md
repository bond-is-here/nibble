# Repository settings baseline

These importable branch rulesets mirror `bond-is-here/ojas` as inspected on September 5, 2026. Files alone do **not** activate GitHub protections. Apply them in Settings → Rulesets → New ruleset → Import a ruleset, then verify both show Active. Avoid importing a duplicate if an equivalent ruleset already exists.

- `main.json`: protect the default branch from deletion and force-push; require a pull request, zero mandatory approvals, squash-only merging, no bypass actors.
- `signed-commits.json`: require verified signatures on every branch, no bypass actors.

General merge settings in Ojas: only squash merging enabled, default squash message uses PR title and description, always suggest branch updates, allow auto-merge, automatically delete merged head branches. No DCO sign-off requirement for web commits.

Actions baseline: allow all actions, full-SHA pinning not required, 90-day log/artifact retention, approval for first-time fork contributors, read-only default workflow token, Actions cannot create/approve PRs. Nibble's workflow explicitly narrows its token to `contents: read` and does not need repository secrets.

Local commits use the owner's existing SSH signing configuration. Do not commit private keys, tokens, signing certificates, or provisioning profiles.
