.PHONY: build clean test

DMD ?= dmd

build:
	dub build --compiler=$(DMD)

clean:
	rm -f -- roaring roaring-test-library *.lst

test:
	dub test --compiler=$(DMD) --coverage && \
	tail -1 source-roaring.lst


