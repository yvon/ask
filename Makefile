FLAGS=-lc -lreadline
SRC=src/ask.zig

all: ask README.md

ask: src/*.zig
	zig build-exe $(FLAGS) $(SRC)

clean:
	rm -f ask *.o

release:
	zig build-exe -O ReleaseSmall -fstrip -fsingle-threaded $(FLAGS) $(SRC)

install:
	cp ask ~/.local/bin

README.md: ./utils/generate_readme.sh src/usage.txt
	sh ./utils/generate_readme.sh > README.md
