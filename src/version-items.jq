# Format an artifact's versions as Alfred items, filtered by a version prefix.
# Enter copies the default format; the cmd modifier copies the other format; the
# alt modifier opens the version in Central.
# --arg coord "group:artifact"  --arg g group  --arg a artifact
# --arg filter version prefix  --arg icon path  --arg open the artifact base url
# --arg primary/other the copy action verbs  --arg primary_label/other_label
[ .[]
  | select(type == "object" and (.v | type) == "string")
  | select($filter == "" or (.v | startswith($filter)))
  | {
      title: .v,
      subtitle: ($primary_label + "  ·  ⌘ " + $other_label + "  ·  ⌥ open in Central"),
      arg: ($primary + " " + $coord + ":" + .v),
      icon: { path: $icon },
      mods: {
        cmd: { valid: true, arg: ($other + " " + $coord + ":" + .v), subtitle: $other_label },
        alt: { valid: true, arg: ("open " + $open + "/" + $g + "/" + $a + "/" + .v), subtitle: "Open this version in Central" }
      }
    }
]
