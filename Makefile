FLAGS=-lc -lreadline

build:
	zig build-exe ask.zig $(FLAGS)

release:
	zig build-exe -O ReleaseSmall -fstrip -fsingle-threaded $(FLAGS) ask.zig

install:
	cp ask ~/.local/bin
