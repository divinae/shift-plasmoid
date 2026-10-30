PLUGIN_ID = com.dv.stand
VERSION := $(shell python3 -c "import json; print(json.load(open('package/metadata.json'))['KPlugin']['Version'])")
ARCHIVE = shift_v$(VERSION).plasmoid

QMLLINT ?= /usr/lib/qt6/bin/qmllint
QMLTESTRUNNER ?= /usr/lib/qt6/bin/qmltestrunner

# Plasma looks a widget's icon up by name in the icon theme and cannot point into the
# package, so the figures are installed as themed icons too: one for the widget list, and
# one per posture for the tooltip.
ICON_DIR = $(or $(XDG_DATA_HOME),$(HOME)/.local/share)/icons/hicolor/scalable/apps

QML_SOURCES = $(wildcard package/contents/ui/*.qml package/contents/ui/lib/*.qml)
PACKAGE_FILES = $(shell find package -type f)

# plasmoid.configuration is an attached property qmllint cannot resolve outside
# plasmashell, so those two categories are pure noise here.
QMLLINT_FLAGS = --unqualified disable --missing-property disable

.PHONY: check lint test audit install upgrade uninstall package clean icons release

check: lint audit test

lint:
	$(QMLLINT) $(QMLLINT_FLAGS) $(QML_SOURCES)

test:
	QT_QPA_PLATFORM=offscreen $(QMLTESTRUNNER) -input tests

# Checks the config keys, the settings pages and the applet agree. qmllint cannot: a cfg_
# alias for a key that does not exist is valid QML, and plasmoid.configuration is an
# attached property it does not resolve.
audit:
	python3 tests/config_audit.py
	python3 tests/theme_audit.py

install: icons
	kpackagetool6 -t Plasma/Applet -i package

upgrade: icons
	kpackagetool6 -t Plasma/Applet -u package

uninstall:
	kpackagetool6 -t Plasma/Applet -r $(PLUGIN_ID)
	rm -f $(ICON_DIR)/$(PLUGIN_ID).svg $(ICON_DIR)/$(PLUGIN_ID)-sit.svg $(ICON_DIR)/$(PLUGIN_ID)-stand.svg

icons:
	install -Dm644 package/contents/icons/person-stand.svg $(ICON_DIR)/$(PLUGIN_ID).svg
	install -Dm644 package/contents/icons/person-sit.svg $(ICON_DIR)/$(PLUGIN_ID)-sit.svg
	install -Dm644 package/contents/icons/person-stand.svg $(ICON_DIR)/$(PLUGIN_ID)-stand.svg

# A .plasmoid is just a zip of the package directory. The name tracks the
# version in metadata.json so the two cannot drift.
package: $(ARCHIVE)

$(ARCHIVE): $(PACKAGE_FILES)
	rm -f $@
	cd package && zip -qr "$(abspath $@)" .
	@echo "built $@"

clean:
	rm -f *.plasmoid

# Keeps the built package in releases/, which is tracked, for the release's download link.
release: $(ARCHIVE)
	mkdir -p releases
	cp $(ARCHIVE) releases/
