# Shared Operator Instructions

Repo-wide doctrine for Discord Preview Fixer. Published with the repository.

## Workflow

- Plan first for multi-step work, then implement after approval. Trivial one-line fixes proceed directly.
- Do not make wide or destructive changes without explicit approval.
- Never push without asking first.
- Before an atomic commit, run `bundle exec rubocop` and `bundle exec rake test`; both must pass. CI (`.github/workflows/minitest.yml`) runs `bundle exec rake` then `bundle exec rubocop`; the lefthook pre-commit hook runs RuboCop against staged `*.rb`.
- Releases: bump both `IMAGE_TAG` and `SENTRY_RELEASE` defaults in `compose.yml`, commit as `Release vX.Y.Z`, then create a signed annotated tag `vX.Y.Z` with `git tag -s vX.Y.Z -m "Release vX.Y.Z"` (`gpg.format=ssh` and `commit.gpgsign=true` are set; `tag.gpgSign` is not, so the `-s` is not automatic) and push it. The tag push is what builds and publishes the GHCR image, so the image tag and `compose.yml` must stay in lockstep. Push the branch and the tag together with `git push --atomic origin master vX.Y.Z`, otherwise the release commit and the image tag can land apart. Note that `.github/workflows/minitest.yml` has an unfiltered `on: push`, so a tag push runs CI as well as the image build; adding `branches: [master]` there would leave releases to the single publish pipeline.

## Rules

- Ruby is pinned to 4.0.9 (`Gemfile`, `mise.toml`, `Dockerfile` base image). Do not bump it without approval.
- Every Ruby file begins with `# frozen_string_literal: true`.
- Adding a link service: subclass `Service`, define `HOST_REGEX` and `REPLACEMENT_HOST` (override `rewrite` only when a path or query change is needed), then add the file to `lib/services.rb` (the manifest required by `main.rb` and the test helper). Nothing else registers it — dispatch is `Service.subclasses`.
- Keep branch coverage at or above the 90% floor enforced in `test/test_helper.rb`. New behavior needs tests.
- Add gems only with explicit approval.

## Style

- RuboCop is authoritative (`.rubocop.yml`): rubocop-minitest, rubocop-rake, and rubocop-sequel are loaded, `NewCops: enable`, `Style/Documentation` disabled, and `Metrics/ClassLength` excluded under `test/**/*` (test classes grow with their cases).
- One class per file. `LinkFixer` owns extraction and rewriting; `Handlers` dispatches events; `HandlerSupport` owns the guard, bot filtering, and embed suppression shared by handlers; `ReplyContent` fits replies to Discord's limit; `Pruner` owns retention cleanup; `Message` owns persistence.
- Private helpers go at the bottom of the class under `private`.
- Documentation and specs are present tense and focused on contracts the code cannot show; do not restate implementation.
