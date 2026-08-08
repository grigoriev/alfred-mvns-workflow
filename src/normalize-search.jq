# Normalize a central.sonatype.com component search into the compact record used
# by search-items.jq. central returns components already ranked by popularity, so
# the order is preserved. uses is the namespace-level app popularity count.
[ .components[]
  | {
      g: .namespace,
      a: .name,
      latestVersion: (.latestVersionInfo.version // "?"),
      p: (.packaging // "jar"),
      uses: (.nsPopularityAppCount // 0)
    }
]
