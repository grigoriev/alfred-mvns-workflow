# <img src="https://raw.githubusercontent.com/grigoriev/alfred-mvns-workflow/main/icon.png" alt="maven" width="32"> Alfred Maven Workflow

![CI](https://github.com/grigoriev/alfred-mvns-workflow/actions/workflows/ci.yml/badge.svg)
[![Release](https://img.shields.io/github/v/release/grigoriev/alfred-mvns-workflow)](https://github.com/grigoriev/alfred-mvns-workflow/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=grigoriev_alfred-mvns-workflow&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=grigoriev_alfred-mvns-workflow)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=grigoriev_alfred-mvns-workflow&metric=coverage)](https://sonarcloud.io/summary/new_code?id=grigoriev_alfred-mvns-workflow)

Search Maven Central and copy a dependency snippet, without leaving Alfred.

## Inspiration and why this exists

Inspired by [xfslove/alfred-mvns](https://github.com/xfslove/alfred-mvns) and
[wangkezun/alfred-mvnrepository-workflow](https://github.com/wangkezun/alfred-mvnrepository-workflow).
This one is a bash rewrite in the style of the sibling grigoriev workflows: no
PHP or scraping, one `jq` pass, a shared updater, a `>` settings menu, tests and
SonarCloud. It searches through Maven Central's official API and opens results on
the modern `central.sonatype.com`.

## Requirements

- [Alfred](https://www.alfredapp.com/) with the Powerpack.
- `jq` (preinstalled on macOS 12+, or `brew install jq`).

## Install

1. Open the [latest release](https://github.com/grigoriev/alfred-mvns-workflow/releases/latest).
2. Under **Assets**, download `Maven.alfredworkflow`.
3. Double click the file to add it to Alfred.

## Usage

```
mvn guava               search Maven Central for artifacts
mvn group:artifact      open the artifact menu (copy Maven, Gradle, versions, open)
mvn group:artifact @    pick a specific version, then copy or open it
mvn >                   settings and updates (default format, delete cache)
```

Results are ranked by popularity, with a usage count in the subtitle. Selecting
an artifact drills into its menu. On a version, <kbd>⏎</kbd> copies the default
format, <kbd>⌘</kbd> copies the other, and <kbd>⌥</kbd> opens the version on
`central.sonatype.com`.

## Configuration

The default copy format (Maven or Gradle) is toggled in `mvn >`. Search results
and version lists are cached for an hour; clear them with `mvn > delete cache`.

## Data source

Search results come from `central.sonatype.com`, ranked by popularity, with a
usage count in the subtitle. Version lists come from Maven Central's Solr API
(`search.maven.org/solrsearch`), which returns clean version strings. Artifacts
open on `central.sonatype.com`. The API access is confined to `src/maven.sh`, so
a future endpoint change is a one-file edit.

## Development

```sh
make lint     # ShellCheck the action scripts
make test     # run the bats tests
make build    # build the workflow bundle
make icons    # regenerate PNG icons from Octicons (macOS, needs librsvg)
```

Icons come from [Octicons](https://github.com/primer/octicons) (MIT).
