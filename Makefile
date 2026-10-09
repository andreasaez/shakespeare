.PHONY: build run test audit verify app install clean

build:
	swift build

run:
	swift run Shakespeare

test:
	swift test

audit:
	./Scripts/audit-privacy.sh

# Run the installed app inside macOS sandboxes that kill it on any network use, process spawn,
# private-folder read or library injection, each with a positive control. Briefly quits the app.
verify:
	./Scripts/verify-local-only.sh

# Release .app in dist/
app: audit
	./Scripts/build-app.sh

# Guided install: build, sign, copy to ~/Applications, launch, and open the permission page
install:
	./Scripts/install.sh

clean:
	rm -rf .build dist
