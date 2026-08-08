# Format the normalized, popularity-ranked search records as Alfred items.
# Selecting an artifact is drill-in only (valid=false), autocompleting
# "group:artifact " into the menu. --arg icon the artifact icon path.
def human($n): if $n >= 1000 then (($n / 1000) | floor | tostring) + "k" else ($n | tostring) end;
[ .[]
  | select(type == "object" and .g and .a)
  | {
      title: (.g + ":" + .a),
      subtitle: ("latest " + .latestVersion + "  ·  " + .p
                 + (if .uses > 0 then "  ·  " + human(.uses) + " users" else "" end)),
      autocomplete: (.g + ":" + .a + " "),
      valid: false,
      icon: { path: $icon }
    }
]
