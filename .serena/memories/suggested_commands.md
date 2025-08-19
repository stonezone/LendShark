# Suggested Commands for LendShark Development

## Build Commands
```bash
# Build for simulator
xcodebuild -workspace LendShark.xcworkspace -scheme LendShark -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build for device
xcodebuild -workspace LendShark.xcworkspace -scheme LendShark -destination 'generic/platform=iOS' build

# Clean build
xcodebuild -workspace LendShark.xcworkspace -scheme LendShark clean
```

## Testing Commands
```bash
# Run unit tests
swift test --package-path LendSharkPackage

# Run all tests via xcodebuild
xcodebuild test -workspace LendShark.xcworkspace -scheme LendShark -destination 'platform=iOS Simulator,name=iPhone 16'

# Run UI tests
xcodebuild test -workspace LendShark.xcworkspace -scheme LendSharkUITests -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Swift Package Commands
```bash
# Update dependencies
swift package update --package-path LendSharkPackage

# Resolve dependencies
swift package resolve --package-path LendSharkPackage

# Generate Xcode project from package
swift package generate-xcodeproj --package-path LendSharkPackage
```

## Code Quality Commands
```bash
# Format Swift code
swift-format -i -r LendSharkPackage/Sources
swift-format -i -r LendShark/

# Lint Swift code
swiftlint --path LendSharkPackage/Sources
swiftlint --path LendShark/

# Check for dependency vulnerabilities
swift package audit --package-path LendSharkPackage
```

## Darwin/macOS Utility Commands
```bash
# List files (macOS)
ls -la

# Find Swift files
find . -name "*.swift" -type f

# Search in files
grep -r "TODO" --include="*.swift" .

# Git commands
git status
git add .
git commit -m "message"
git push

# Open in Xcode
open LendShark.xcworkspace

# Check Swift version
swift --version

# Check Xcode version
xcodebuild -version
```

## Development Workflow Commands
```bash
# 1. Before starting work
git pull
swift package resolve --package-path LendSharkPackage

# 2. After making changes
swiftlint --path LendSharkPackage/Sources --fix
swift-format -i -r LendSharkPackage/Sources
swift test --package-path LendSharkPackage

# 3. Before committing
xcodebuild test -workspace LendShark.xcworkspace -scheme LendShark -destination 'platform=iOS Simulator,name=iPhone 16'
git diff
git add -p

# 4. Build and run
xcodebuild -workspace LendShark.xcworkspace -scheme LendShark -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/LendShark.app
xcrun simctl launch booted com.stonezone.LendShark
```
