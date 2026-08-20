.PHONY: help setup test check run apk apk-release release e2e

API_URL  ?= http://127.0.0.1:9000/v1
LIVE_API ?= https://story-story-api-huxg0j-fe9bbd-13-53-86-234.sslip.io/v1
REPO     ?= Deepak-GitHub1474/story
# The version is pubspec's alone. Bump it there, nowhere else.
VERSION   = $(shell awk '/^version:/{split($$2,v,"+"); print v[1]}' pubspec.yaml)

help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

setup: ## Install dependencies
	flutter pub get

test: ## Run the unit tests
	flutter test

check: ## Analyze and test
	flutter analyze
	flutter test

run: ## Run on the connected device
	flutter run --dart-define=STORY_API_BASE_URL=$(API_URL)

apk: ## Build a debug APK: make apk API_URL=http://192.168.1.38:9000/v1
	flutter build apk --debug --dart-define=STORY_API_BASE_URL=$(API_URL)

apk-release: ## Build the signed arm64 release APK against the live API
	flutter build apk --release --target-platform android-arm64 \
		--dart-define=STORY_API_BASE_URL=$(LIVE_API)
	@ls -lh build/app/outputs/flutter-apk/app-release.apk

release: apk-release ## Publish that APK to GitHub Releases as v$(VERSION)
	@test -n "$(VERSION)" || { echo "no version in pubspec.yaml"; exit 1; }
	@cp build/app/outputs/flutter-apk/app-release.apk build/story.apk
	gh release create v$(VERSION) build/story.apk \
		--repo $(REPO) --title "STORY $(VERSION)" --generate-notes
	@echo "https://github.com/$(REPO)/releases/latest"

e2e: ## Start a test-profile API from ../backend, run the full suite, tear it down
	@cd ../backend && RATE_LIMIT_ENABLED=false MONGODB_DB_NAME=story_e2e \
		uv run uvicorn app.main:app \
		--host 127.0.0.1 --port 9000 > /tmp/story-e2e.log 2>&1 & \
		echo $$! > /tmp/story-e2e.pid
	@until curl -sf --max-time 2 http://127.0.0.1:9000/v1/health/ready >/dev/null; do sleep 1; done
	@flutter test --run-skipped; status=$$?; \
		kill `cat /tmp/story-e2e.pid` 2>/dev/null; rm -f /tmp/story-e2e.pid; \
		exit $$status
