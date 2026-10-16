CONFIG ?= $(HOME)/KeyRemapperMac/config.json
PROFILE ?= 0
SYMBOLS := KeyRemapper/Resources/symbols.json
ICON_SVG := images/icon.svg
MENUBAR_ICON_SVG := images/menubar-icon.svg
APP_ICONSET := KeyRemapper/Assets.xcassets/AppIcon.appiconset
MENUBAR_IMAGESET := KeyRemapper/Assets.xcassets/MenuBarIcon.imageset

FRAMEWORKS := -framework AppKit -framework IOKit -framework ApplicationServices

.PHONY: test test-runtime test-app test-config build install dev-app dev-build dev icon release-patch release-minor release-major

test:
	g++ -o Tests/output -std=c++17 Tests/index.cpp && ./Tests/output

test-runtime:
	mkdir -p build && clang++ -std=c++17 -fobjc-arc -o build/runtime-tests Tests/runtime.mm $(FRAMEWORKS) && build/runtime-tests Tests/runtime.json $(SYMBOLS)

test-app:
	Tests/app.sh

test-config:
	g++ -o Tests/output.config -std=c++17 Tests/configTests.cpp && ./Tests/output.config "$(CONFIG)" $(SYMBOLS)

build:
	xcodebuild -quiet -project KeyRemapper.xcodeproj -target KeyRemapper -configuration Debug CODE_SIGNING_ALLOWED=NO build

install:
	Scripts/install.sh

dev-app:
	Scripts/dev-app.sh

dev-build:
	mkdir -p build && clang++ -std=c++17 -fobjc-arc -o build/keyremapper-dev Dev/main.mm $(FRAMEWORKS)

dev: dev-build
	sudo build/keyremapper-dev "$(CONFIG)" $(SYMBOLS) --profile $(PROFILE) $(if $(LOG),--log)

# Requires rsvg-convert (brew install librsvg)
icon:
	for size in 16 32 64 128 256 512 1024; do rsvg-convert -w $$size -h $$size $(ICON_SVG) -o $(APP_ICONSET)/$$size.png; done
	cp $(MENUBAR_ICON_SVG) $(MENUBAR_IMAGESET)/icon.svg

release-patch release-minor release-major:
	Scripts/release.sh $(@:release-%=%)
