#!/bin/bash

. src/workflow_handler.sh
. src/media.sh
. src/maven.sh
. src/globals.sh

# Single entry point behind the "mvn" keyword. Called two ways from Alfred:
#   list mode (Script Filter): . src/mvn.sh list "{query}"
#   run mode  (Run Script):    . src/mvn.sh run  "{query}"
#
# Query grammar:
#   mvn <text>            -> search Maven Central for artifacts
#   mvn group:artifact    -> (drill in) the artifact action menu
#   mvn group:artifact @  -> pick a version, then copy or open it
#   mvn >                 -> global commands (default format, delete cache, update)
#
# Items carry an action in their arg: "maven g:a:v", "gradle g:a:v",
# "coord g:a:v" or "open <url>". Run mode dispatches on the first word.

mode="$1"
query="$2"

# Base url for opening artifacts on central.sonatype.com.
ARTIFACT_URL="${MVN_ARTIFACT_URL:-https://central.sonatype.com/artifact}"

# Print a Script Filter feedback object wrapping a JSON items array.
print_items() {
  local items="$1"
  printf '{"items":%s}\n' "$items"
  return 0
}

# Reopen Alfred on a query so the list refreshes in place after an action.
alfred_search() {
  local query="$1"
  osascript - "$query" <<'APPLESCRIPT'
on run argv
  tell application id "com.runningwithcrayons.Alfred" to search (item 1 of argv)
end run
APPLESCRIPT
  return 0
}

# Queue a menu entry when its token matches the filter prefix.
# $1 token  $2 filter  $3 title  $4 subtitle  $5 arg  $6 valid  $7 icon  $8 autocomplete
menu_item() {
  local token="$1" filter="$2" title="$3" subtitle="$4" arg="$5" valid="$6" icon="$7" auto="$8"
  case "$token" in
    "$filter"*) add_result "" "$arg" "$title" "$subtitle" "$icon" "$valid" "$auto" ;;
    *) : ;;
  esac
  return 0
}

# The action menu for a selected "group:artifact", built around its latest
# version, filtered by a prefix.
artifact_menu() {
  local coord="$1" filter="$2" group artifact versions latest
  group="${coord%%:*}"
  artifact="${coord#*:}"
  versions="$(mvn_versions "$group" "$artifact")"
  latest="$(jq -r '.[0].v // empty' <<< "$versions" 2>/dev/null)"
  if [[ -z "$latest" ]]; then
    add_result "" "" "No versions found" "Check the artifact name" "$ICON_ARTIFACT" "no"
    get_json_results
    return 0
  fi
  menu_item maven       "$filter" "Copy Maven"       "<dependency> for $coord:$latest"                "maven $coord:$latest"  "yes" "$ICON_COPY"    ""
  menu_item gradle      "$filter" "Copy Gradle"      "implementation '$coord:$latest'"                "gradle $coord:$latest" "yes" "$ICON_COPY"    ""
  menu_item coordinates "$filter" "Copy coordinates" "$coord:$latest"                                 "coord $coord:$latest"  "yes" "$ICON_COPY"    ""
  menu_item versions    "$filter" "Versions"         "Pick a specific version"                        ""                      "no"  "$ICON_VERSION" "$coord @"
  menu_item open        "$filter" "Open in Central"  "central.sonatype.com/artifact/$group/$artifact" "open $ARTIFACT_URL/$group/$artifact" "yes" "$ICON_OPEN" ""
  get_json_results
  return 0
}

# The version picker for "group:artifact @<prefix>".
versions_picker() {
  local coord="$1" filter="$2" group artifact versions items
  local primary other primary_label other_label fmt
  group="${coord%%:*}"
  artifact="${coord#*:}"
  fmt="$(get_pref format 0)"
  [[ -n "$fmt" ]] || fmt="maven"
  if [[ "$fmt" == "gradle" ]]; then
    primary="gradle"; other="maven"; primary_label="Copy Gradle"; other_label="Copy Maven"
  else
    primary="maven"; other="gradle"; primary_label="Copy Maven"; other_label="Copy Gradle"
  fi
  versions="$(mvn_versions "$group" "$artifact")"
  items="$(jq -c -f src/version-items.jq \
    --arg coord "$coord" --arg g "$group" --arg a "$artifact" --arg filter "$filter" \
    --arg icon "$ICON_VERSION" --arg open "$ARTIFACT_URL" \
    --arg primary "$primary" --arg other "$other" \
    --arg primary_label "$primary_label" --arg other_label "$other_label" <<< "$versions" 2>/dev/null)"
  if [[ -z "$items" || "$items" == "[]" ]]; then
    add_result "" "" "No matching versions" "Type part of a version number" "$ICON_VERSION" "no"
    get_json_results
    return 0
  fi
  print_items "$items"
  return 0
}

# Search Maven Central and list matching artifacts. The fetch is async: a cold
# cache shows a "Searching..." placeholder and reruns, so the Script Filter never
# blocks on the network.
search() {
  local query="$1" docs stale items tick dots
  if [[ "${#query}" -lt 2 ]]; then
    add_result "" "" "Keep typing to search Maven Central" "At least 2 characters" "$ICON_SEARCH" "no"
    get_json_results
    return 0
  fi
  docs="$(mvn_search "$query")"
  stale=$?
  if [[ -z "$docs" ]]; then
    # cold cache: show an animated placeholder and rerun until the background
    # fetch fills the cache, so a slow search is visibly in progress.
    tick="${search_tick:-0}"
    case "$tick" in
      1) dots=".." ;;
      2) dots="..." ;;
      *) dots="." ;;
    esac
    add_result "" "" "Searching Maven Central$dots" "for \"$query\"" "$ICON_SEARCH" "no"
    add_variable search_tick "$(( (tick + 1) % 3 ))"
    set_rerun 0.3
    get_json_results
    return 0
  fi
  items="$(jq -c -f src/search-items.jq --arg icon "$ICON_ARTIFACT" <<< "$docs" 2>/dev/null)"
  if [[ -z "$items" || "$items" == "[]" ]]; then
    add_result "" "" "No artifacts found" "Try another query" "$ICON_SEARCH" "no"
    [[ "$stale" -eq 1 ]] && set_rerun 0.5
    get_json_results
    return 0
  fi
  if [[ "$stale" -eq 1 ]]; then
    printf '{"rerun":0.5,"items":%s}\n' "$items"
  else
    print_items "$items"
  fi
  return 0
}

# Run mode: dispatch the item action.
if [[ "$mode" == "run" ]]; then
  action="${query%% *}"
  payload="${query#"$action"}"
  payload="${payload# }"
  case "$action" in
    maven)  maven_snippet "$payload" | pbcopy ;;
    gradle) gradle_snippet "$payload" | pbcopy ;;
    coord)  printf '%s' "$payload" | pbcopy ;;
    open)   open "$payload" ;;
    format) set_pref format "$payload" 0; alfred_search "mvn >" ;;
    delete) run_delete "$payload" ;;
    autoupdate) set_autoupdate "$payload" ;;
    http://*|https://*) autoupdate_clear; [[ -f src/update.sh ]] && . src/update.sh "$query" ;;
    *) : ;;
  esac
  exit
fi

# List mode
if [[ "$query" == ">"* ]]; then
  sub="${query#>}"
  sub="${sub# }"
  if [[ "$sub" == update* ]]; then
    if [[ -f src/update.sh ]]; then
      . src/update.sh ""
    else
      add_result "" "" "Updater unavailable" "Rebuild the workflow bundle" "$ICON_UPDATE" "no"
      get_json_results
    fi
  else
    globals_menu "$sub"
  fi
  exit
fi

if [[ -z "$query" ]]; then
  autoupdate_refresh
  autoupdate_banner
  add_result "" "" "Search Maven Central" "Type an artifact name, e.g. guava" "$ICON_SEARCH" "no"
  get_json_results
  exit
fi

first="${query%% *}"
if [[ "$query" == *" "* ]] && [[ "$first" == *:* ]]; then
  rest="${query#* }"
  if [[ "$rest" == @* ]]; then
    versions_picker "$first" "${rest#@}"
  else
    artifact_menu "$first" "$rest"
  fi
else
  search "$query"
fi
