SRC=src/ask.zig

all: ask README.md

ask: src/*.zig
	zig build-exe $(SRC)

clean:
	rm -f ask *.o

release-%:
	zig build-exe -O ReleaseSmall -fstrip -fsingle-threaded -target $* $(SRC) && \
	tar -czf ask-$*.tar.gz ask

releases: release-x86_64-linux release-aarch64-macos

release:
	zig build-exe -O ReleaseSmall -fstrip -fsingle-threaded $(SRC)

install:
	cp ask ~/.local/bin

README.md: ./utils/generate_readme.sh src/usage.txt
	sh ./utils/generate_readme.sh > README.md
