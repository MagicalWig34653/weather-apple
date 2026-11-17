#!/bin/bash
# macOS >= 15, Swift >= 6.0. No dependencies, package resolution or product project changes.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
harness_dir="$(mktemp -d "${TMPDIR:-/tmp}/weather-watch-radar.XXXXXX")"
trap 'rm -rf "$harness_dir"' EXIT
mkdir -p "$harness_dir/Sources/WeatherWatchRadar" "$harness_dir/Tests/WeatherWatchRadarTests"
for source in "$repo_root"/Shared/*.swift "$repo_root"/Shared/Data/*.swift; do
    cp "$source" "$harness_dir/Sources/WeatherWatchRadar/"
done
for relative in \
    Weather/Data/RadarBackend.swift Weather/Data/RadarHistory.swift Weather/Data/DWDRadarTimeline+App.swift \
    WeatherWatch/Radar/RadarCrop.swift WeatherWatch/Radar/WatchRadarStore.swift WeatherWatch/Radar/WebPLosslessDecoder.swift; do
    cp "$repo_root/$relative" "$harness_dir/Sources/WeatherWatchRadar/"
done
cp "$repo_root/WeatherTests/WatchRadarTests.swift" "$harness_dir/Tests/WeatherWatchRadarTests/"
cat > "$harness_dir/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "WeatherWatchRadar",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "WeatherWatchRadar"),
        .testTarget(name: "WeatherWatchRadarTests", dependencies: ["WeatherWatchRadar"],
                    swiftSettings: [.define("WATCH_RADAR_TESTS")])
    ]
)
PACKAGE
# All inputs are local; forward e.g. --filter WatchRadarTests/testPlayback.
swift test --disable-sandbox --disable-automatic-resolution --package-path "$harness_dir" "$@"
