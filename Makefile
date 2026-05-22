.PHONY: generate build test app-build lint clean tools

PROJECT := WhisperIntent.xcodeproj
SCHEME  := WhisperIntent
DESTINATION := platform=iOS Simulator,name=iPhone 15

generate:
	xcodegen generate

build:
	cd Packages/WhisperIntentCore && swift build

test:
	cd Packages/WhisperIntentCore && swift test

app-build: $(PROJECT)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' build

$(PROJECT):
	xcodegen generate

lint:
	swiftformat --lint .
	swiftlint --strict --quiet App Packages/WhisperIntentCore/Sources Packages/WhisperIntentCore/Tests Packages/WhisperIntentCore/Package.swift

clean:
	rm -rf .build/ DerivedData/ $(PROJECT)
	cd Packages/WhisperIntentCore && swift package clean

tools:
	@command -v xcodegen >/dev/null  || (echo "Install: brew install xcodegen"  && exit 1)
	@command -v swiftformat >/dev/null || (echo "Install: brew install swiftformat" && exit 1)
	@command -v swiftlint >/dev/null  || (echo "Install: brew install swiftlint"  && exit 1)
	@command -v gitleaks >/dev/null   || (echo "Install: brew install gitleaks"   && exit 1)
	@echo "All tools present."
