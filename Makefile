format:
	dart format .

format-check:
	dart format -o none --set-exit-if-changed .

lint:
	flutter analyze

check: format-check lint

dev:
	flutter run -d 1371604144000UP                         
