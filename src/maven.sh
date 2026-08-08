#!/bin/bash

# Maven Central access and dependency snippets. Search and versions use the
# official Solr API at search.maven.org (the web UI redirects to
# central.sonatype.com, but this API path still serves clean JSON). Responses
# are cached under "$alfred_workflow_cache". The one place to change if the API
# ever moves is SEARCH_URL.

. src/cache.sh

# Search runs against central.sonatype.com, whose results are ranked by
# popularity and carry usage counts. Versions come from the Maven Central
# repository metadata on repo1.maven.org, a CDN that build tools already hit, so
# it is fast and not gated behind the search UI's Cloudflare challenge.
CENTRAL_SEARCH_URL="${MVN_CENTRAL_SEARCH_URL:-https://central.sonatype.com/api/internal/browse/components}"
METADATA_URL="${MVN_METADATA_URL:-https://repo1.maven.org/maven2}"
SEARCH_TTL="${MVN_SEARCH_TTL:-3600}"
VERSIONS_TTL="${MVN_VERSIONS_TTL:-3600}"
USER_AGENT="${MVN_USER_AGENT:-alfred-mvns-workflow (+https://github.com/grigoriev/alfred-mvns-workflow)}"

# Fetch a url with bounded timeouts and a User-Agent, so a slow or rate-limiting
# endpoint never hangs the script.
mvn_curl() {
  local url="$1"
  curl -sfL --connect-timeout 3 --max-time 8 -A "$USER_AGENT" "$url" 2>/dev/null
  return 0
}

# A cache key derived from a string (only safe filename characters).
cache_key() {
  local prefix="$1" text="$2"
  printf '%s_%s.json' "$prefix" "$(printf '%s' "$text" | tr -c 'A-Za-z0-9.' '_')"
  return 0
}

# Fetch search results from central.sonatype.com and cache the normalized,
# popularity-ranked list (only when the response parses, so a Cloudflare
# challenge page never poisons the cache).
fetch_search() {
  local query="$1" key="$2" body data normalized
  body="$(jq -cn --arg q "$query" '{searchTerm: $q, page: 0, size: 20}')"
  data="$(curl -sfL --connect-timeout 3 --max-time 8 -A "$USER_AGENT" \
    -H 'Content-Type: application/json' --data "$body" "$CENTRAL_SEARCH_URL" 2>/dev/null)"
  [[ -n "$data" ]] || return 0
  normalized="$(printf '%s' "$data" | jq -c -f src/normalize-search.jq 2>/dev/null)"
  [[ -n "$normalized" ]] && printf '%s' "$normalized" | cache_set "$key"
  return 0
}

# Kick a background search fetch, deduplicated by a lock directory so rapid
# reruns for the same query never pile up requests on the endpoint.
fetch_search_async() {
  local query="$1" key="$2" lock
  [[ "${MVN_FETCH:-1}" == "0" ]] && return 0
  lock="$(cache_path "$key").lock"
  mkdir "$lock" 2>/dev/null || return 0
  ( fetch_search "$query" "$key"; rmdir "$lock" 2>/dev/null ) >/dev/null 2>&1 &
  disown 2>/dev/null || true
  return 0
}

# Search Maven Central. Prints cached docs when available; returns 1 when the
# cache is cold or stale, so the caller shows "Searching..." and reruns while a
# background fetch refreshes it. This keeps the Script Filter instant.
mvn_search() {
  local query="$1" key file
  key="$(cache_key search "$query")"
  file="$(cache_path "$key")"
  if cache_fresh "$key" "$SEARCH_TTL"; then
    cache_get "$key"
    return 0
  fi
  fetch_search_async "$query" "$key"
  [[ -f "$file" ]] && cache_get "$key"
  return 1
}

# List an artifact's versions, newest first, as a JSON array of {v}. Read from
# the repository's maven-metadata.xml (parsed with grep/sed, no perl) and cached
# per artifact. Fetched synchronously, since a drill-in is a deliberate action.
mvn_versions() {
  local group="$1" artifact="$2" key path data versions
  key="$(cache_key versions "$group:$artifact")"
  if ! cache_fresh "$key" "$VERSIONS_TTL"; then
    path="$(printf '%s' "$group" | tr '.' '/')/$artifact"
    data="$(mvn_curl "$METADATA_URL/$path/maven-metadata.xml")"
    if [[ -n "$data" ]]; then
      versions="$(printf '%s' "$data" | grep -oE '<version>[^<]+</version>' \
        | sed -E 's/<[^>]+>//g' | jq -Rn '[inputs] | reverse | map({v: .})' 2>/dev/null)"
      [[ -n "$versions" ]] && printf '%s' "$versions" | cache_set "$key"
    fi
  fi
  cache_get "$key"
  return 0
}

# Split "group:artifact:version" into g a v and print a Maven dependency block.
maven_snippet() {
  local coord="$1" group artifact version rest
  group="${coord%%:*}"; rest="${coord#*:}"
  artifact="${rest%%:*}"; version="${rest##*:}"
  printf '<dependency>\n    <groupId>%s</groupId>\n    <artifactId>%s</artifactId>\n    <version>%s</version>\n</dependency>' \
    "$group" "$artifact" "$version"
  return 0
}

# A Gradle (Groovy) dependency line for "group:artifact:version".
gradle_snippet() {
  local coord="$1"
  printf "implementation '%s'" "$coord"
  return 0
}
