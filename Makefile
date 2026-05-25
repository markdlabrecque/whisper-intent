.PHONY: generate build test app-build app-build-release release-archive release-ipa lint clean tools verify doctor

PROJECT := WhisperIntent.xcodeproj
SCHEME  := WhisperIntent
DESTINATION ?= generic/platform=iOS Simulator
DEVICE_DESTINATION ?= generic/platform=iOS

BUILD_DIR        := build
ARCHIVE_PATH     := $(BUILD_DIR)/WhisperIntent.xcarchive
EXPORT_PATH      := $(BUILD_DIR)/export
EXPORT_OPTIONS   := ExportOptions.plist
GIT_SHA          := $(shell git rev-parse --short HEAD)

generate:
	xcodegen generate

build:
	cd Packages/WhisperIntentCore && swift build

SIMULATOR_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro

test: $(PROJECT)
	cd Packages/WhisperIntentCore && swift test
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(SIMULATOR_DESTINATION)' test

app-build: $(PROJECT)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' build

## Build the app target in Release configuration on the simulator destination.
## Useful for catching #if DEBUG drift without needing signing certs.
app-build-release: $(PROJECT)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -configuration Release build

## Produce a signed .xcarchive for the iOS device destination.
##
## Requires: a configured Apple Developer team identifier in Xcode (or the
## DEVELOPMENT_TEAM build setting) and a provisioning profile that matches
## com.marklabrecque.whisperintent. Override TEAM_ID=XXXXXXXXXX on the
## command line if not picked up from the local Xcode environment.
##
## Embeds the current git SHA as CURRENT_PROJECT_VERSION so archive
## provenance is traceable. Bump MARKETING_VERSION via project.yml for
## human-facing version numbers.
release-archive: $(PROJECT)
	@mkdir -p $(BUILD_DIR)
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DEVICE_DESTINATION)' \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) \
		CURRENT_PROJECT_VERSION=$(GIT_SHA) \
		$(if $(TEAM_ID),DEVELOPMENT_TEAM=$(TEAM_ID),) \
		archive
	@echo "Archive: $(ARCHIVE_PATH)"

## Export an IPA from the most recent archive.
##
## Requires ExportOptions.plist at the repo root. A template is generated on
## first run; fill in teamID, signingStyle, and provisioningProfiles before
## a real upload. The IPA lands in build/export/WhisperIntent.ipa.
release-ipa: $(ARCHIVE_PATH) $(EXPORT_OPTIONS)
	@mkdir -p $(EXPORT_PATH)
	xcodebuild \
		-exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist $(EXPORT_OPTIONS)
	@echo "IPA: $(EXPORT_PATH)/WhisperIntent.ipa"

$(EXPORT_OPTIONS):
	@echo "ExportOptions.plist missing — writing a template. Fill in teamID before using." >&2
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>method</key>' \
		'  <string>app-store</string>' \
		'  <key>teamID</key>' \
		'  <string>TEAM_ID_HERE</string>' \
		'  <key>signingStyle</key>' \
		'  <string>automatic</string>' \
		'  <key>stripSwiftSymbols</key>' \
		'  <true/>' \
		'  <key>uploadSymbols</key>' \
		'  <true/>' \
		'  <key>uploadBitcode</key>' \
		'  <false/>' \
		'</dict>' \
		'</plist>' > $(EXPORT_OPTIONS)

$(PROJECT):
	xcodegen generate

lint:
	swiftformat --lint .
	swiftlint --strict --quiet App Packages/WhisperIntentCore/Sources Packages/WhisperIntentCore/Tests Packages/WhisperIntentCore/Package.swift

clean:
	rm -rf .build/ DerivedData/ $(BUILD_DIR) $(PROJECT)
	cd Packages/WhisperIntentCore && swift package clean

tools:
	@command -v xcodegen >/dev/null  || (echo "Install: brew install xcodegen"  && exit 1)
	@command -v swiftformat >/dev/null || (echo "Install: brew install swiftformat" && exit 1)
	@command -v swiftlint >/dev/null  || (echo "Install: brew install swiftlint"  && exit 1)
	@command -v gitleaks >/dev/null   || (echo "Install: brew install gitleaks"   && exit 1)
	@echo "All tools present."

## Aggregate pre-push check. Runs tests, lint, and both Debug + Release
## simulator builds. Fails fast on the first red.
verify: test lint app-build app-build-release
	@echo "✅ verify passed: tests, lint, debug build, release build."

## Self-diagnostic. Prints a per-row pass/fail report on local prerequisites:
## required CLI tools, Xcode toolchain, WhisperKit model files, Fastlane
## environment (if .env is present), and signing-related configuration.
## Always exits 0 — meant for humans, not CI gating.
doctor:
	@scripts/doctor.sh
