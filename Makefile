# Default target for current platform
build:
	zig build-exe ask.zig

install: build
	cp ask ~/.local/bin

# Cross-compilation targets with organized output
linux-x86_64:
	mkdir -p dist/linux-x86_64
	zig build-exe ask.zig -target x86_64-linux -femit-bin=dist/linux-x86_64/ask

macos-x86_64:
	mkdir -p dist/macos-x86_64
	zig build-exe ask.zig -target x86_64-macos -femit-bin=dist/macos-x86_64/ask

macos-arm64:
	mkdir -p dist/macos-arm64
	zig build-exe ask.zig -target aarch64-macos -femit-bin=dist/macos-arm64/ask

windows-x86_64:
	mkdir -p dist/windows-x86_64
	zig build-exe ask.zig -target x86_64-windows -femit-bin=dist/windows-x86_64/ask.exe

# Build all targets
all: linux-x86_64 macos-x86_64 macos-arm64 windows-x86_64

# Create zip archives for distribution
zip: all
	cd dist && zip -r ask-linux-x86_64.zip linux-x86_64/
	cd dist && zip -r ask-macos-x86_64.zip macos-x86_64/
	cd dist && zip -r ask-macos-arm64.zip macos-arm64/
	cd dist && zip -r ask-windows-x86_64.zip windows-x86_64/

# Clean build artifacts
clean:
	rm -f ask ask.exe
	rm -rf dist/

.PHONY: build install linux-x86_64 macos-x86_64 macos-arm64 windows-x86_64 all clean zip