#!/bin/zsh
# Nutzung: run-test.sh <udid> <testName> <derivedData> <logfile>   (Env TEST_RUNNER_SHOT_* wird durchgereicht)
# Startet das Shots-UI-Test-Bundle (tools/project.yml, per xcodegen erzeugt) mit 300 s Zeitlimit.
cd "${SHOTS_PROJECT_DIR:-.}"
perl -e 'alarm 300; exec @ARGV' xcodebuild test -project ShotsUI.xcodeproj -scheme ShotsUI -destination "id=$1" \
  -derivedDataPath "$3" -only-testing:ShotsUITests/ShotsUITests/$2 CODE_SIGNING_ALLOWED=NO > "$4" 2>&1
echo "$2: $(grep -E 'error:|TEST ' "$4" | head -2)"
