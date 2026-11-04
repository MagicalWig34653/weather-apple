#!/bin/zsh
# Prüft, dass AppIconOption.all, project.yml (ALTERNATE_APPICON_NAMES), Alternates/*.icon und IconPreviews.xcassets übereinstimmen.
set -eu
cd "$(dirname "$0")/.."
swift_ids=$(grep -o '\.alt("[A-Za-z0-9]*"' Weather/Icons/AppIconOption.swift | sed 's/.*("//; s/"//' | sort)
yml_names=$(grep 'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES' project.yml | sed 's/.*: *"//; s/"//' | tr ' ' '\n' | sort)
dir_names=$(ls Weather/Resources/Icon/Alternates | sed 's/\.icon$//' | sort)
prev_ids=$(ls Weather/Resources/IconPreviews.xcassets | grep '^Preview.*imageset$' | sed 's/^Preview//; s/\.imageset$//' | grep -v '^Standard$' | sort)
swift_names=$(print -l ${=swift_ids} | sed 's/^/Alt/' | sort)
fail=0
[[ "$swift_names" == "$yml_names" ]] || { print -u2 "FEHLER: AppIconOption.swift und project.yml unterscheiden sich"; fail=1; }
[[ "$yml_names" == "$dir_names" ]] || { print -u2 "FEHLER: project.yml und Alternates/*.icon unterscheiden sich"; fail=1; }
[[ "$swift_ids" == "$prev_ids" ]] || { print -u2 "FEHLER: AppIconOption.swift und IconPreviews.xcassets unterscheiden sich"; fail=1; }
[[ -d Weather/Resources/IconPreviews.xcassets/PreviewStandard.imageset ]] || { print -u2 "FEHLER: PreviewStandard fehlt"; fail=1; }
for n in ${=dir_names}; do grep -q "Alternates/$n.icon" project.yml || { print -u2 "FEHLER: $n nicht als Ressource in project.yml"; fail=1; }; done
(( fail == 0 )) && print "OK: $(print -l ${=yml_names} | wc -l | tr -d ' ') Alternativen konsistent"
exit $fail
