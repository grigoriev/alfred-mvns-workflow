#!/bin/bash

# Global commands behind "mvn >": the default copy format, cache maintenance and
# updates. The autoupdate helpers come from the shared, fetched src/autoupdate.sh.

. src/media.sh
. src/autoupdate.sh

# Lowercase a string.
mvn_lower() {
  local text="$1"
  printf '%s' "$text" | tr '[:upper:]' '[:lower:]'
  return 0
}

# Queue a global command when its token contains the filter (case-insensitive).
# $1 token  $2 filter  $3 title  $4 subtitle  $5 arg  $6 valid  $7 icon  $8 autocomplete
global_item() {
  local token="$1" filter="$2" title="$3" subtitle="$4" arg="$5" valid="$6" icon="$7" auto="$8"
  case "$(mvn_lower "$token")" in
    *"$(mvn_lower "$filter")"*) add_result "" "$arg" "$title" "$subtitle" "$icon" "$valid" "$auto" ;;
    *) : ;;
  esac
  return 0
}

# The global command menu, filtered by a substring.
globals_menu() {
  local filter="$1" fmt
  fmt="$(get_pref format 0)"
  [[ -n "$fmt" ]] || fmt="maven"
  if [[ "$fmt" == "gradle" ]]; then
    global_item "default format" "$filter" "Default format: Gradle" "Switch the enter action to Maven" "format maven" "yes" "$ICON_COPY" ""
  else
    global_item "default format" "$filter" "Default format: Maven" "Switch the enter action to Gradle" "format gradle" "yes" "$ICON_COPY" ""
  fi
  global_item "delete cache" "$filter" "Delete cache" "Drop cached search results and versions" "delete cache" "yes" "$ICON_TRASH" ""
  autoupdate_menu "$filter" "$ICON_UPDATE"
  get_json_results
  return 0
}

# Delete the cache. $1 = cache.
run_delete() {
  local target="$1"
  case "$target" in
    cache)
      if [[ -n "$alfred_workflow_cache" ]]; then
        rm -rf "$alfred_workflow_cache"
        mkdir -p "$alfred_workflow_cache"
      fi
      ;;
    *) : ;;
  esac
  return 0
}
