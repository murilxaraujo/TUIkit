.PHONY: build test example lint docs docs-static release-checklist

build:
	swift build

test:
	swift test --parallel

example:
	swift run TUIkitExample

lint:
	swiftlint

docs:
	swift package --disable-sandbox preview-documentation --target TUIkit

docs-static:
	swift package --allow-writing-to-directory docc-output generate-documentation --target TUIkit --output-path docc-output --transform-for-static-hosting

release-checklist:
	./scripts/release-validation-checklist.sh
