---
name: release-update
description: Refresh the Ruby patch pin, gems, and pinned GitHub Actions of Discord Preview Fixer, then cut a new minor release. Use when asked to update Ruby/gems/Actions or to create a release.
---

# Release update

Dependency refresh plus a minor release, as four local commits, stopping before any push.
The doctrine this encodes lives in `.operator-shared/operator.md` (Workflow and Rules); do not
duplicate it, follow it.

Work top to bottom. Track the four commits as separate todo items. If a step cannot complete
cleanly, stop at that step and report — never skip verification to reach the release commit.

## Pre-flight

1. `git status --short` must be empty on `master`. `ratelimit.log` is an untracked runtime log:
   never stage it.
2. `git fetch --tags && git pull --ff-only`.
3. Baseline must be green before anything changes:
   `bundle install && bundle exec rake test && bundle exec rubocop`.
4. Note the current version: `grep -n 'IMAGE_TAG' compose.yml` and
   `git describe --tags --abbrev=0` — they must agree.

Helper script (relative to this skill directory): `scripts/upstream.sh ruby-patch <minor>` prints the
newest stable patch for a Ruby minor.

## Commit 1 — Ruby patch pin

Only a patch bump within the current minor is allowed (e.g. 4.0.9 → 4.0.10). Crossing a Ruby
minor or major needs explicit approval.

1. Read the current pin from `Gemfile` (`ruby '4.0.9'`) and keep only `MAJOR.MINOR`.
2. `scripts/upstream.sh ruby-patch 4.0` gives the newest stable patch. Prereleases are filtered
   out by the script; do not pick one.
3. If it equals the current pin, skip this commit entirely and say so. Do not create an empty
   commit.
4. Confirm the base image exists before editing:
   `curl -sS 'https://registry.hub.docker.com/v2/repositories/library/ruby/tags?page_size=100&name=<VERSION>' | grep -o '"name":"<VERSION>-alpine"'`
   An empty match means the image is not published yet — stop and report.
5. Update every pin site (grep `ruby '`, `ruby =`, `FROM ruby:` first; currently five):
   - `Gemfile` — `ruby '<VERSION>'`
   - `mise.toml` — `[tools] ruby = "<VERSION>"`
   - `Dockerfile` — `FROM ruby:<VERSION>-alpine AS base`
   - `README.md` — `You need Ruby <VERSION> or later`
   - `.operator-shared/operator.md` — the "Ruby is pinned to …" rule line
6. `bundle install` rewrites the `RUBY VERSION` stanza of `Gemfile.lock`; that lockfile change
   belongs in this commit.
7. Verify: `ruby -v` reports the new version, and `bundle exec rake test` still passes.
8. Commit `Bump Ruby to <VERSION>` with a body stating the old → new pin.

## Commit 2 — Gems

1. `bundle update --all`.
2. Review `git diff Gemfile.lock`: list the bumps, and call out every major-version jump.
   Ignore platform-stanza noise only after confirming it is noise (a `x86_64-linux-musl`
   addition is expected when resolving for the Alpine image; a removed platform is not).
3. `bundle exec rubocop` and `bundle exec rake test` must pass. Fix mechanical fallout
   (new cops, formatting) here. If a major bump changes behavior and the fix is not mechanical,
   stop and ask before forcing it.
4. Commit `Update gems` with the bumped gems in the body.
5. If nothing moved, skip the commit and say so.

## Commit 3 — Pinned GitHub Actions

Actions are pinned to a full 40-character commit SHA with a trailing `# vX.Y.Z` comment in
`.github/workflows/minitest.yml` and `.github/workflows/build-docker-image.yml`. Use `actions-up`
(azat-io) rather than resolving tags by hand: it scans the workflows, resolves releases, and
writes the SHA and comment together. It runs through `npx`, so nothing is added to the repo.
Export a token first (`GITHUB_TOKEN="$(gh auth token)"`, or ask if `gh` is unauthenticated) — it
raises the GitHub API limit from 60 to 5000.

1. Survey, read-only: `npx -y actions-up@2 --json --exclude '^runner/' > /tmp/actions-up.json`.
   `--json` never writes files. Read each `updates[]` entry's `currentVersion` → `latestVersion`
   and `isBreaking`. Also read `skipped`, `blockedByMode`, `blockedByAge`, `blockedByTrust`, and
   `blockedAsDowngrade` — if any are non-empty, say so in the report instead of dropping them.
2. Apply: `npx -y actions-up@2 --yes --quiet --exclude '^runner/'`.
   - Always pass `--exclude '^runner/'`: `runs-on` labels are pinned deliberately
     (`ubuntu-24.04`) and runner images are out of scope.
   - Never pass `--style preserve` or `--style semver`; the default `sha` style is the doctrine.
   - Majors are allowed and are flagged, not blocked. Report every `isBreaking` update.
   - Releases younger than one day are held by the cool-down. Keep that default; add
     `--min-age 0` only if the user explicitly wants same-day releases.
   - If a release exists but its tags are ahead, `--prefer-tags` is the escape hatch — offer it,
     do not assume it.
3. Verify the diff is actions-only: `git diff --stat .github/workflows`, then check the diff has
   only `uses:` lines where the SHA and the `# vX.Y.Z` comment move together. A mismatched pair,
   a changed `runs-on`, or a touched non-`uses` line is a defect.
4. Validate the YAML parses: `ruby -ryaml -e 'ARGV.each { |f| YAML.load_file(f) }' .github/workflows/*.yml`.
5. Commit `Update pinned GitHub Actions` with the old → new tags in the body, marking majors as
   breaking.
6. Re-run step 1: a second survey must report no updates, proving the apply was complete and
   that re-running is safe.
7. If no updates were available, skip the commit and say so.

## Gate before the release

All four checks must pass on the updated tree:

- `bundle exec rake test`
- `bundle exec rubocop`
- `docker build --tag discord-preview-fixer:ci .` (CI builds this, so catch it locally)
- the working tree is clean

This workstation has no Docker daemon, and the rootless Podman fallback cannot create
containers here (`mount proc: Operation not permitted`), so the image build is not locally
runnable. When that is still true, run the other three checks, then state plainly in the report
that the image was not built locally and that `.github/workflows/minitest.yml`'s `docker` job and
the tag-triggered publish run are the only proof. Do not substitute a Dockerfile edited for
`docker.io/library/...` — that verification is fake.

## Commit 4 — Minor release

1. Take the current version from `compose.yml` (e.g. `v1.8.2`). Next minor is
   `v<MAJOR>.<MINOR + 1>.0` — the patch is reset to zero (`v1.8.2` → `v1.9.0`).
2. Edit both `compose.yml` defaults to the new tag:
   `image: …:${IMAGE_TAG:-vX.Y.Z}` and `SENTRY_RELEASE: ${IMAGE_TAG:-vX.Y.Z}`.
   Exactly two occurrences; the publish workflow greps for the two and fails the build otherwise.
3. Commit `Release vX.Y.Z` (nothing else in this commit).
4. Create the signed annotated tag explicitly — `tag.gpgSign` is not configured:
   `git tag -s vX.Y.Z -m "Release vX.Y.Z"`
5. Verify: `git tag -v vX.Y.Z` reports a good signature and `git show vX.Y.Z --stat` points at
   the release commit.

## Stop and ask

Do not push. Print the exact command and wait for approval:

```
git push --atomic origin master vX.Y.Z
```

Explain what the push unlocks: CI on `master`, and the image build triggered by the tag. The
atomic push keeps the release commit and the image tag from landing apart.

If approval is given, push, then verify with `gh run list --limit 5` and confirm the
`Create and publish a Docker image` run succeeded — it re-checks that `compose.yml` matches the
tag.

## Gotchas

- The Ruby pin lives in five places. Missing `README.md` or the `operator.md` rule line leaves a
  documented version that contradicts the code; missing `Dockerfile` breaks the image build.
- `build-docker-image.yml` triggers on `v1.**`, so a `v2.0.0` tag would publish nothing. Raise
  this when the major ever changes; do not fix it silently mid-release.
- Open Dependabot branches may already carry some of these bumps; this skill supersedes them.
  Deleting those branches is a separate, explicitly approved action.
- `actions-up` also detects `runs-on` drift and reusable-workflow calls. Both are out of scope
  here: the `--exclude '^runner/'` flag keeps runner labels alone, and a reusable workflow that
  the repo does not call is a signal to stop and report, not to edit.
- `mise ls-remote` filters by the machine's minimum release age and may under-report; the script
  filters prereleases, and Docker Hub is the authority on what can actually be pulled.
- RuboCop and the test suite are both CI gates. A green local run is the only proof the update
  commit is releasable.

## Report

Summarize as a table: each commit (or the reason it was skipped), old → new values, the tag, and
the pending push command.
