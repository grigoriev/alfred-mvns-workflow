#!/usr/bin/env bats

# Unit tests for src/maven.sh. curl is mocked (tests/mocks/bin).

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  mkdir -p "$alfred_workflow_cache" "$alfred_workflow_data"
}

@test "maven.sh: fetch_search caches normalized popularity-ranked results" {
  run bash -c '. src/maven.sh; k="$(cache_key search guava)"; fetch_search guava "$k"; cat "$(cache_path "$k")"'
  echo "$output" | jq -e '.[0].g == "com.google.guava" and .[0].uses == 48000' >/dev/null
  [ -f "$alfred_workflow_cache/search_guava.json" ]
}

@test "maven.sh: mvn_search serves a warm cache" {
  printf '[{"g":"com.google.guava","a":"guava","latestVersion":"33.4.8-jre","p":"bundle","uses":48000}]' > "$alfred_workflow_cache/search_guava.json"
  run bash -c '. src/maven.sh; mvn_search "guava"'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].a == "guava"' >/dev/null
}

@test "maven.sh: mvn_search reports a cold cache" {
  run bash -c 'export MVN_FETCH=0; . src/maven.sh; mvn_search "guava"; echo "rc=$?"'
  [[ "$output" == *"rc=1"* ]]
}

@test "maven.sh: mvn_versions returns versions newest first" {
  run bash -c '. src/maven.sh; mvn_versions com.google.guava guava'
  echo "$output" | jq -e '.[0].v == "33.4.8-jre" and (length == 3)' >/dev/null
}

@test "maven.sh: maven_snippet builds a dependency block" {
  run bash -c '. src/maven.sh; maven_snippet "g:a:1.0"'
  [[ "$output" == *"<groupId>g</groupId>"* ]]
  [[ "$output" == *"<artifactId>a</artifactId>"* ]]
  [[ "$output" == *"<version>1.0</version>"* ]]
}

@test "maven.sh: gradle_snippet builds an implementation line" {
  run bash -c '. src/maven.sh; gradle_snippet "g:a:1.0"'
  [ "$output" == "implementation 'g:a:1.0'" ]
}
