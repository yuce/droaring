.PHONY: build clean test

DMD ?= dmd

build: ext/roaring.o source/roaring/roaring.d source/roaring/c.d
	$(DMD) -lib -of=libroaring.a source/roaring/roaring.d source/roaring/c.d
	ar rcs libroaring.a ext/roaring.o

ext/roaring.o:
	$(CC) -c -o ext/roaring.o ext/roaring.c

clean:
	rm -f -- libroaring.a roaring-test-library *.lst
	rm ext/roaring.o

test:
	dub test --compiler=$(DMD) --coverage && \
	tail -1 source-roaring.lst
