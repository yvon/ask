build:
	zig build-exe ask.zig

install: build
	cp ask ~/.local/bin