#!/bin/zsh
# App-Store-Screenshots "Showers" (nur Deutsch) neu erzeugen. Siehe docs/app-store-screenshots.md.
# Nutzung:  tools/screenshots.sh build                 App fuer den Simulator bauen (Debug, ohne Signing)
#           tools/screenshots.sh iphone-pro|iphone-max|ipad   Geraet zuruecksetzen, Orte anlegen, alle Motive aufnehmen
# Umgebung: DEVELOPER_DIR (Xcode), SHOTS_WORK (Scratch, Standard /private/tmp/showers-shots-work)
set -u
REPO=${0:A:h:h}
TOOLS=$REPO/design/appstore-screenshots/tools
WORK=${SHOTS_WORK:-/private/tmp/showers-shots-work}
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app}
APP=$WORK/app-dd/Build/Products/Debug-iphonesimulator/Weather.app
BID=de.linolaske.showernow
mkdir -p $WORK/ui $WORK/raw

udid() { xcrun simctl list devices available -j | python3 -c "import json,sys;n=sys.argv[1];print(next(d['udid'] for v in json.load(sys.stdin)['devices'].values() for d in v if d['name']==n))" "$1"; }

if [[ ${1:-} == build ]]; then
  cd $REPO && xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath $WORK/app-dd CODE_SIGNING_ALLOWED=NO build | tail -2
  exit
fi

case ${1:-} in
  iphone-pro) NAME="SN Shots iPhone Pro"; OUT=$REPO/design/appstore-screenshots/iphone/1206x2622/de ;;
  iphone-max) NAME="SN Shots iPhone Max"; OUT=$REPO/design/appstore-screenshots/iphone/1320x2868/de ;;
  ipad)       NAME="SN Shots iPad 13";    OUT=$REPO/design/appstore-screenshots/ipad/2064x2752/de ;;
  *) echo "Nutzung: $0 build|iphone-pro|iphone-max|ipad"; exit 1 ;;
esac
U=$(udid $NAME); RAW=$WORK/raw/$1; rm -rf $RAW; mkdir -p $RAW $OUT

# UI-Test-Bundle (nur Screenshots, nicht Teil von Weather.xcodeproj)
cp $TOOLS/project.yml $TOOLS/ShotsUITests.swift $TOOLS/run-test.sh $WORK/ui/
(cd $WORK/ui && xcodegen generate >/dev/null)

run() { # run <test> [VAR=val ...]
  local t=$1; shift
  ( for kv in "$@"; do export TEST_RUNNER_$kv; done
    export TEST_RUNNER_SHOT_DIR=$RAW SHOTS_PROJECT_DIR=$WORK/ui
    zsh $WORK/ui/run-test.sh $U $t $WORK/ui-dd $WORK/log-$1.txt )
}
scene() { run testScene SHOT_SCENE=$1 SHOT_NAME=$2 "${@:3}"; }  # scene <scene> <dateiname> [VAR=val ...]

xcrun simctl shutdown all 2>/dev/null; xcrun simctl erase $U; xcrun simctl boot $U; xcrun simctl bootstatus $U -b >/dev/null
xcrun simctl ui $U appearance light
xcrun simctl install $U $APP
xcrun simctl privacy $U grant location $BID
xcrun simctl status_bar $U override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl launch $U $BID >/dev/null; sleep 20; xcrun simctl terminate $U $BID
for c in Hamburg München Berlin; do run testAddPlace SHOT_CITY=$c; done

# Radar mit Archivregen: 48 h Rueckblick, Position 0.84 = Messung mit Regenband bei Hamburg (haengt vom Zeitpunkt ab, vorher pruefen)
scene radar    01-regenradar        SHOT_ARGS="-radarPastHours 48" SHOT_POS=${SHOT_RAIN_POS:-0.84}
scene details  02-ortsdetails
scene temp     03-temperatur        SHOT_POS=0.3 SHOT_READ=1
scene warnings 04-warnungen         SHOT_PLACE=Berlin SHOT_ARGS="-UITestWarnings fixture"
scene regionnew 06-region           && mv $RAW/06-region-places.png $RAW/07-orte-regionen.png
scene humidity 05-feuchte-wald      SHOT_FOREST=1 SHOT_POS=0.3 SHOT_READ=1
xcrun simctl ui $U appearance dark
scene radar    08-regenradar-dunkel SHOT_ARGS="-radarPastHours 48" SHOT_POS=${SHOT_RAIN_POS:-0.84}
xcrun simctl ui $U appearance light
xcrun simctl status_bar $U clear 2>/dev/null; xcrun simctl status_bar $U override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
rm -f $OUT/*.png; cp $RAW/[0-9]*.png $OUT/; ls -l $OUT
