# Shared Operator Instructions

Repo-wide doctrine for Discord Preview Fixer. Published with the repository.

## Workflow

- Plan first for multi-step work, then implement after approval. Trivial one-line fixes proceed directly.
- Do not make wide or destructive changes without explicit approval.
- Never push without asking first.
- Before an atomic commit, run `bundle exec rubocop` and `bundle exec rake test`; both must pass. CI (`.github/workflows/minitest.yml`) runs `bundle exec rake` then `bundle exec rubocop`; the lefthook pre-commit hook runs RuboCop against staged `*.rb`.
- Releases: bump both `IMAGE_TAG` and `SENTRY_RELEASE` defaults in `compose.yml`, commit as `Release vX.Y.Z`, then create a signed annotated tag `vX.Y.Z` (`tag.gpgSign=true`, `gpg.format=ssh`) and push it. The tag push is what builds and publishes the GHCR image, so the image tag and `compose.yml` must stay in lockstep.

## Rules

- Ruby is pinned to 4.0.7 (`Gemfile`, `mise.toml`). Do not bump it without approval.
- Every Ruby file begins with `# frozen_string_literal: true`.
- Adding a link service: subclass `Service`, define `HOST_REGEX` and `REPLACEMENT_HOST`, then require the file in both `main.rb` and `test/test_helper.rb`. Nothing else registers it — dispatch is `Service.subclasses`.
- Keep branch coverage at or above the 90% floor enforced in `test/test_helper.rb`. New behavior needs tests.
- Add gems only with explicit approval.

## Style

- RuboCop is authoritative (`.rubocop.yml`): rubocop-minitest, rubocop-rake, and rubocop-sequel are loaded, `NewCops: enable`, `Style/Documentation` disabled.
- One class per file. `LinkFixer` owns extraction and rewriting; `Handlers` owns Discord event side effects; `Message` owns persistence.
- Private helpers go at the bottom of the class under `private`.
- Documentation and specs are present tense and focused on contracts the code cannot show; do not restate implementation.
