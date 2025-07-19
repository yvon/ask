SRC=src/ask.zig

all: ask README.md

ask: src/*.zig
	zig build-exe $(SRC)

clean:
	rm -f ask *.o

release:
	zig build-exe -O ReleaseSmall -fstrip -fsingle-threaded $(SRC)

archive: release
	tar -czf ask-$(shell uname -s)-$(shell uname -m).tar.gz ask

install:
	cp ask ~/.local/bin

README.md: ./utils/generate_readme.sh src/usage.txt
	sh ./utils/generate_readme.sh > README.md
