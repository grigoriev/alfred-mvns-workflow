#!/usr/bin/env bats

# Integration tests for src/mvn.sh. curl, pbcopy, open and osascript are mocked.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  mkdir -p "$alfred_workflow_cache" "$alfred_workflow_data"
}

@test "mvn.sh: search lists artifacts from a warm cache, most popular first" {
  printf '[{"g":"com.google.guava","a":"guava","latestVersion":"33.4.8-jre","p":"bundle","uses":48000},{"g":"com.example","a":"beta","latestVersion":"1.0","p":"jar","uses":0}]' > "$alfred_workflow_cache/search_guava.json"
  run bash -c '. src/mvn.sh list "guava"'
  echo "$output" | jq -e '.items[0].title == "com.google.guava:guava"' >/dev/null
  echo "$output" | jq -e '.items[0].subtitle | contains("48k users")' >/dev/null
  echo "$output" | jq -e '.items[0].valid == false and .items[0].autocomplete == "com.google.guava:guava "' >/dev/null
}

@test "mvn.sh: a cold search shows an animated searching placeholder" {
  run bash -c 'export MVN_FETCH=0; . src/mvn.sh list "guava"'
  echo "$output" | jq -e '.rerun == 0.3' >/dev/null
  echo "$output" | jq -e '.items[0].title == "Searching Maven Central."' >/dev/null
  echo "$output" | jq -e '.variables.search_tick == "1"' >/dev/null
}

@test "mvn.sh: the searching dots advance with the tick" {
  run bash -c 'export MVN_FETCH=0 search_tick=2; . src/mvn.sh list "guava"'
  echo "$output" | jq -e '.items[0].title == "Searching Maven Central..."' >/dev/null
  echo "$output" | jq -e '.variables.search_tick == "0"' >/dev/null
}

@test "mvn.sh: a short query asks for more characters" {
  run bash -c '. src/mvn.sh list "g"'
  echo "$output" | jq -e '.items[0].title == "Keep typing to search Maven Central"' >/dev/null
}

@test "mvn.sh: empty query shows a hint" {
  run bash -c '. src/mvn.sh list ""'
  echo "$output" | jq -e '.items[0].title == "Search Maven Central"' >/dev/null
}

@test "mvn.sh: the artifact menu offers copy and open actions" {
  run bash -c '. src/mvn.sh list "com.google.guava:guava "'
  echo "$output" | jq -e '[.items[].title] == ["Copy Maven","Copy Gradle","Copy coordinates","Versions","Open in Central"]' >/dev/null
  echo "$output" | jq -e '.items[] | select(.title=="Copy Maven") | .arg == "maven com.google.guava:guava:33.4.8-jre"' >/dev/null
}

@test "mvn.sh: the artifact menu filters by a prefix" {
  run bash -c '. src/mvn.sh list "com.google.guava:guava open"'
  echo "$output" | jq -e '[.items[].title] == ["Open in Central"]' >/dev/null
}

@test "mvn.sh: the version picker copies maven by default, with gradle and open mods" {
  run bash -c '. src/mvn.sh list "com.google.guava:guava @33.4"'
  echo "$output" | jq -e '.items[0].title == "33.4.8-jre"' >/dev/null
  echo "$output" | jq -e '.items[0].arg == "maven com.google.guava:guava:33.4.8-jre"' >/dev/null
  echo "$output" | jq -e '.items[0].mods.cmd.arg == "gradle com.google.guava:guava:33.4.8-jre"' >/dev/null
  echo "$output" | jq -e '.items[0].mods.alt.arg | startswith("open https://central.sonatype.com/artifact/com.google.guava/guava/33.4.8-jre")' >/dev/null
}

@test "mvn.sh: run maven copies a dependency block" {
  export PBCOPY_LOG="$BATS_TEST_TMPDIR/pb.log"
  run bash -c '. src/mvn.sh run "maven g:a:1.0"'
  grep -q "<artifactId>a</artifactId>" "$PBCOPY_LOG"
}

@test "mvn.sh: run gradle copies an implementation line" {
  export PBCOPY_LOG="$BATS_TEST_TMPDIR/pb.log"
  run bash -c '. src/mvn.sh run "gradle g:a:1.0"'
  grep -q "implementation 'g:a:1.0'" "$PBCOPY_LOG"
}

@test "mvn.sh: run coord copies the coordinates" {
  export PBCOPY_LOG="$BATS_TEST_TMPDIR/pb.log"
  run bash -c '. src/mvn.sh run "coord g:a:1.0"'
  grep -qx "g:a:1.0" "$PBCOPY_LOG"
}

@test "mvn.sh: run open dispatches to open" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/mvn.sh run "open https://central.sonatype.com/artifact/g/a"'
  grep -q "central.sonatype.com/artifact/g/a" "$OPEN_LOG"
}

@test "mvn.sh: > lists default format, delete cache and update items" {
  run bash -c '. src/mvn.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Default format: Maven") != null and index("Delete cache") != null and index("Check for updates") != null' >/dev/null
}

@test "mvn.sh: run format switches the default format" {
  export OSASCRIPT_LOG="$BATS_TEST_TMPDIR/osa.log"
  run bash -c '. src/mvn.sh run "format gradle"'
  run bash -c '. src/mvn.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Default format: Gradle") != null' >/dev/null
}

@test "mvn.sh: gradle default makes the version enter copy gradle" {
  bash -c '. src/mvn.sh run "format gradle"'
  run bash -c '. src/mvn.sh list "com.google.guava:guava @33.4"'
  echo "$output" | jq -e '.items[0].arg == "gradle com.google.guava:guava:33.4.8-jre"' >/dev/null
  echo "$output" | jq -e '.items[0].mods.cmd.arg == "maven com.google.guava:guava:33.4.8-jre"' >/dev/null
}

@test "mvn.sh: run delete cache clears the cache dir" {
  printf 'x' > "$alfred_workflow_cache/search_x.json"
  run bash -c '. src/mvn.sh run "delete cache"'
  [ ! -f "$alfred_workflow_cache/search_x.json" ]
}

@test "mvn.sh: run ignores an unknown action" {
  run bash -c '. src/mvn.sh run "bogus payload"'
  [ "$status" -eq 0 ]
}
