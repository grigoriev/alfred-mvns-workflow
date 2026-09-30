# CLAUDE.md

Alfred workflow that searches Maven Central and copies a Maven or Gradle dependency snippet.
Plain bash, Alfred JSON feedback, bats tests, a shared self-updater.
Keyword: `mvn`. Artifact: `Maven.alfredworkflow`.

## Layout

- `src/mvn.sh` - the entry point. It takes `mode` (`list` for the Script Filter, `run` for the Run Script) and `query`.
- `src/maven.sh` - all HTTP access: search on `central.sonatype.com`, versions from `repo1.maven.org` metadata. Keep API changes in this file.
- `src/cache.sh` - the response cache under `$alfred_workflow_cache`, one hour TTL.
- `src/globals.sh` - the `mvn >` settings menu (`globals_menu`).
- `src/normalize-search.jq`, `src/search-items.jq`, `src/version-items.jq` - extracted jq programs.
- `src/workflow_handler.sh` - shared JSON feedback helpers, identical in all sibling workflows.
- `src/media.sh` - icon paths. `icons/` holds the PNGs, built from Octicons.
- `src/update.sh`, `src/autoupdate.sh` - fetched at build time from `alfred-workflow-updater`. Gitignored, never committed.
- `info.plist` - Alfred objects and the workflow `version`.
- `tests/*.bats`, including `tests/mvn_cover_tests.bats` for extra paths and `tests/perf_tests.bats`.
- `tests/mocks/bin/` - fake `curl`, `open`, `osascript` and `pbcopy`.

## Commands

```sh
make lint       # ShellCheck mvn.sh, maven.sh, cache.sh, globals.sh in Docker
make test       # fetch the updater, then run bats tests (macOS)
make coverage   # bats under kcov in Docker, writes sonar-coverage.xml
make build      # fetch the updater, smoke-test it, zip Maven.alfredworkflow
make icons      # regenerate PNG icons from Octicons (macOS, needs librsvg)
make clean      # remove the artifact, fetched updater and coverage
```

1. Install tools with `brew install bats-core jq`.
2. `make lint SHELLCHECK=shellcheck` uses a local ShellCheck instead of Docker.
3. `make test` needs network access, because it fetches the updater bundle first.
4. `MVN_CENTRAL_SEARCH_URL`, `MVN_METADATA_URL` and the `MVN_*_TTL` env vars override endpoints and TTLs in tests.

## Constraints and conventions

- Scripts run under stock macOS `/bin/bash` 3.2.
- No bash 4+ features: no `mapfile`, `readarray`, `declare -A`, `${var,,}` or `${var^^}`.
- Check a construct with `/bin/bash -c '...'`. zsh and Homebrew bash 5 hide 3.2 gaps.
- No perl. Use `awk`, `sed`, `jq` or bash. The metadata XML is parsed with `grep` and `sed`.
- Build Script Filter JSON with `add_result` and `get_json_results`, never by hand.
- The Script Filter must feel instant. Spawn `jq` once per run, not once per result.
- Put multi-line jq or awk programs in `src/*.jq` or `src/*.awk` and call them with `-f`.
- Every `curl` call has bounded timeouts and a User-Agent, through `mvn_curl`.
- Cache a response only when it parses. A Cloudflare challenge page must never poison the cache.
- Settings and updates live behind the `mvn >` menu. `globals_menu` calls the shared `autoupdate_menu`.
- Update logic lives only in `alfred-workflow-updater`. Never reimplement it here.
- SonarCloud shell rules: `[[ ]]` not `[ ]`, positional params into named lowercase `local`s, snake_case functions, explicit `return` at function end, a `*)` default in every `case`, HTTPS for `curl`.

## Review focus

Flag these in a pull request:

- Any bash 4+ feature, or any perl call.
- A new or changed function without a bats test. A bug fix without a test that fails before the fix.
- Unquoted variable expansions, especially the query and Maven coordinates.
- `jq`, `curl` or a subshell spawned inside a per-result loop.
- A multi-line jq or awk program embedded in `$(...)` instead of a `src/*.jq` or `src/*.awk` file.
- Hand-built JSON strings instead of `add_result` and `json_encode`.
- HTTP access outside `src/maven.sh`, a plain `http://` URL, or a `curl` call without timeouts.
- A test that hits the real network instead of the `curl` mock.
- A violation of the Sonar shell rules listed above.
- A new `src/*.sh` script that the `SCRIPTS` list in the Makefile does not lint.
- Update or autoupdate logic added here instead of in `alfred-workflow-updater`.
- A committed `src/update.sh` or `src/autoupdate.sh`.
- A change to `.github/workflows/ci.yml`, `release.yml` or `bump-version.yml` in this repo only. These are byte-identical across all 8 Alfred repos.
- A user-facing change without an entry under `## [Unreleased]` in `CHANGELOG.md`.
- A behavior or data source change without a README update.

Commit, branch and pull request rules are in `CONTRIBUTING.md`.

## CI and release

- `ci.yml`: ShellCheck, actionlint and zizmor on Ubuntu, bats on `macos-latest`, the build, and a SonarCloud scan with kcov coverage.
- The version lives in `info.plist`. `make print-version` and `make set-version VERSION=x.y.z` read and write it.
- A maintainer runs **Bump Version & Release**. It cuts the `CHANGELOG.md` section and tags `v*`.
- `release.yml` builds with `CHECK_PROVENANCE=1`, attests the artifact, and publishes an immutable release.
