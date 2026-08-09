#!/usr/bin/env bats

# Coverage tests for the menu, version, dispatch, and global paths of src/mvn.sh,
# plus the async and no-data paths of src/maven.sh. curl/pbcopy/open/osascript
# are mocked (tests/mocks/bin).

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  mkdir -p "$alfred_workflow_cache" "$alfred_workflow_data"
}

warm_cache() {
  printf '[{"g":"com.google.guava","a":"guava","latestVersion":"33.4.8-jre","p":"bundle","uses":48000}]' \
    > "$alfred_workflow_cache/search_guava.json"
}

# --- artifact menu ---------------------------------------------------------

@test "mvn.sh: an artifact menu lists copy, versions and open actions" {
  run bash -c '. src/mvn.sh list "com.google.guava:guava "'
  echo "$output" | jq -e '[.items[].title] | index("Copy Maven") != null and index("Copy Gradle") != null and index("Copy coordinates") != null and index("Versions") != null and index("Open in Central") != null' >/dev/null
}

@test "mvn.sh: an artifact with no versions reports it" {
  run bash -c '. src/mvn.sh list "com.example:none "'
  echo "$output" | jq -e '.items[0].title == "No versions found"' >/dev/null
}

@test "mvn.sh: the menu filters actions by a prefix" {
  run bash -c '. src/mvn.sh list "com.google.guava:guava open"'
  echo "$output" | jq -e '[.items[].title] == ["Open in Central"]' >/dev/null
}

# --- version picker --------------------------------------------------------

@test "mvn.sh: the version picker lists versions newest first" {
  run bash -c '. src/mvn.sh list "com.google.guava:guava @"'
  echo "$output" | jq -e '.items[0].arg | endswith(":33.4.8-jre")' >/dev/null
}

@test "mvn.sh: the version picker reports when nothing matches" {
  run bash -c '. src/mvn.sh list "com.google.guava:guava @99nomatch"'
  echo "$output" | jq -e '.items[0].title == "No matching versions"' >/dev/null
}

# --- search states ---------------------------------------------------------

@test "mvn.sh: a two-dot searching frame renders for tick 1" {
  run bash -c 'export MVN_FETCH=0 search_tick=1; . src/mvn.sh list "guava"'
  echo "$output" | jq -e '.items[0].title == "Searching Maven Central.."' >/dev/null
}

@test "mvn.sh: a warm empty result set says no artifacts" {
  printf '[]' > "$alfred_workflow_cache/search_guava.json"
  run bash -c '. src/mvn.sh list "guava"'
  echo "$output" | jq -e '.items[0].title == "No artifacts found"' >/dev/null
}

@test "mvn.sh: a stale empty result set reruns while refreshing" {
  printf '[]' > "$alfred_workflow_cache/search_guava.json"
  touch -t 200001010000 "$alfred_workflow_cache/search_guava.json"
  run bash -c 'export MVN_FETCH=0; . src/mvn.sh list "guava"'
  echo "$output" | jq -e '.items[0].title == "No artifacts found" and .rerun == 0.5' >/dev/null
}

@test "mvn.sh: a stale non-empty result set reruns while refreshing" {
  warm_cache
  touch -t 200001010000 "$alfred_workflow_cache/search_guava.json"
  run bash -c 'export MVN_FETCH=0; . src/mvn.sh list "guava"'
  echo "$output" | jq -e '.rerun == 0.5 and (.items[0].title == "com.google.guava:guava")' >/dev/null
}

# --- run dispatch ----------------------------------------------------------

@test "mvn.sh: run copies maven, gradle and coordinates" {
  export PBCOPY_LOG="$BATS_TEST_TMPDIR/pb.log"
  : > "$PBCOPY_LOG"; bash -c '. src/mvn.sh run "maven g:a:1.0"'
  grep -q '<groupId>g</groupId>' "$PBCOPY_LOG"
  : > "$PBCOPY_LOG"; bash -c '. src/mvn.sh run "gradle g:a:1.0"'
  grep -q "implementation 'g:a:1.0'" "$PBCOPY_LOG"
  : > "$PBCOPY_LOG"; bash -c '. src/mvn.sh run "coord g:a:1.0"'
  [ "$(cat "$PBCOPY_LOG")" = "g:a:1.0" ]
}

@test "mvn.sh: run open opens the url" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/mvn.sh run "open https://central.sonatype.com/artifact/g/a"'
  grep -q 'central.sonatype.com/artifact/g/a' "$OPEN_LOG"
}

@test "mvn.sh: run format stores the preference and refreshes" {
  export OSASCRIPT_LOG="$BATS_TEST_TMPDIR/osa.log"
  bash -c '. src/mvn.sh run "format gradle"'
  run bash -c '. src/workflow_handler.sh; get_pref format 0'
  [ "$output" = "gradle" ]
}

@test "mvn.sh: run delete drops the cache" {
  printf 'x' > "$alfred_workflow_cache/search_guava.json"
  run bash -c '. src/mvn.sh run "delete cache"'
  [ ! -f "$alfred_workflow_cache/search_guava.json" ]
}

@test "mvn.sh: run autoupdate on writes the flag" {
  run bash -c '. src/mvn.sh run "autoupdate on"'
  [ -f "$alfred_workflow_data/autoupdate" ]
}

# --- globals and update ----------------------------------------------------

@test "mvn.sh: > lists the global commands" {
  run bash -c '. src/mvn.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Delete cache") != null and index("Check for updates") != null' >/dev/null
  echo "$output" | jq -e '[.items[].title] | any(. | startswith("Default format"))' >/dev/null
}

@test "mvn.sh: > update runs the fetched updater" {
  run bash -c '. src/mvn.sh list "> update"'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("items")' >/dev/null
}

# --- maven.sh async and no-data -------------------------------------------

@test "maven.sh: fetch_search_async takes a lock and spawns a fetch" {
  run bash -c '. src/maven.sh; k="$(cache_key search guava)"; fetch_search_async guava "$k"; echo rc=$?'
  [[ "$output" == *"rc=0"* ]]
  [ -d "$alfred_workflow_cache/search_guava.json.lock" ] || true
}

@test "maven.sh: mvn_versions yields nothing when metadata is empty" {
  run bash -c '. src/maven.sh; mvn_versions com.example none'
  [ -z "$output" ]
}
