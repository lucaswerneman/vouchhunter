#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 -m unittest discover -s backend/tests -v
swift test --package-path packages/HuntCore --scratch-path /private/tmp/vouchhunter-swift-build
xcodebuild -project ios/Vouchhunter.xcodeproj -scheme Vouchhunter -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/vouchhunter-derived CODE_SIGN_IDENTITY=- build
