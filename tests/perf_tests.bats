#!/usr/bin/env bats

# Performance guard for the Script Filter. Times the render hot paths (search
# results and version lists) over large warmed caches and fails only on an
# order-of-magnitude regression, such as re-introducing a per-item subprocess
# spawn. The measured time is printed so a slowdown is visible in the output.
#
# Times with jq's `now` (already a dependency); BSD `date` has no %N.

BUDGET_MS=1500
ITEMS=100

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  mkdir -p "$alfred_workflow_cache" "$alfred_workflow_data"
}

now_ms() { jq -n 'now * 1000 | floor'; }

@test "perf: search render over many artifacts stays fast" {
  local file start end ms
  file="$(bash -c '. src/maven.sh; cache_path "$(cache_key search guava)"')"
  jq -n "[range($ITEMS) | {g: \"com.example.g\(.)\", a: \"artifact\(.)\", latestVersion: \"1.0.\(.)\", p: \"jar\", uses: (. * 100)}]" > "$file"
  start="$(now_ms)"
  run bash -c '. src/mvn.sh list "guava"'
  end="$(now_ms)"
  ms=$(( end - start ))
  [ "$status" -eq 0 ]
  echo "# search render ($ITEMS artifacts): ${ms}ms (budget ${BUDGET_MS}ms)" >&3
  [ "$ms" -lt "$BUDGET_MS" ]
}

@test "perf: version render over many versions stays fast" {
  local file start end ms
  file="$(bash -c '. src/maven.sh; cache_path "$(cache_key versions com.example:lib)"')"
  jq -n "[range($ITEMS) | {v: \"1.0.\(.)\", timestamp: 1700000000000}]" > "$file"
  start="$(now_ms)"
  run bash -c '. src/mvn.sh list "com.example:lib @"'
  end="$(now_ms)"
  ms=$(( end - start ))
  [ "$status" -eq 0 ]
  echo "# version render ($ITEMS versions): ${ms}ms (budget ${BUDGET_MS}ms)" >&3
  [ "$ms" -lt "$BUDGET_MS" ]
}
