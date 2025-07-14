# Default target for current platform
build:
	zig build-exe ask.zig -lc -lreadline

release:
	zig build-exe -O ReleaseSmall -fstrip -fsingle-threaded ask.zig

windows:
	zig build-exe -O ReleaseSmall -fstrip -fsingle-threaded -target x86_64-windows ask.zig -lws2_32 -lcrypt32 -ladvapi32

install:
	cp ask ~/.local/bin
