.PHONY: format format-check lint check dev build

format:
	dart format .

format-check:
	dart format -o none --set-exit-if-changed .

lint:
	flutter analyze

check: format-check lint

dev:
	flutter run -d 1371604144000UP

build:
	flutter build apk --debug

install:
	adb -s 1371604144000UP install -r build\app\outputs\flutter-apk\app-debug.apk
