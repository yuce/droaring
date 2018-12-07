<a href="https://travis-ci.org/yuce/droaring"><img src="https://api.travis-ci.org/yuce/droaring.svg?branch=master"></a>
<a href='https://coveralls.io/github/yuce/droaring?branch=master'><img src='https://coveralls.io/repos/github/yuce/droaring/badge.svg?branch=master' alt='Coverage Status' /></a>

<img src="https://github.com/yuce/yuce.github.io/blob/master/roaring.jpg" style="float: right" align="right" height="256" width="256">

# Experimental D Roaring Bitmaps Library

[Roaring Bitmaps](http://roaringbitmap.org) are compressed bit arrays which can store a huge amount of bits in a space efficient manner. The bitmap is organized so that adding/removing bits is very fast and don't require unpacking the whole bitmap. You can use bit arrays for efficient set operations.

Check out [Pilosa](https://www.pilosa.com) for an open source distributed index which uses roaring bitmaps.

This library wraps [CRoaring](https://github.com/RoaringBitmap/CRoaring).

## Limitations

* Bitmap size is (*currently*) limited to `uint.max`, which is `2^^32 - 1`. This is a limitation of CRoaring. See: https://github.com/RoaringBitmap/CRoaring/issues/1

## Requirements

* A recent D compiler. Tested with DMD v2.079.0, LDC 1.8.0 and GDC v2.068.2_gcc6.
* C compiler with C11 support.
* Tested on Linux, FreeBSD, MacOS and Windows (only with 64bit).

## Install

### Using DUB

Add `roaring` to your DUB dependencies. E.g.:
```json
{
    "name": "roar",
    "description": "A minimal D application.",
    "dependencies": {
        "roaring": {
            "version": "0.1.8"
        }
    }
}
```

### Without DUB

Assuming you've built the library and `$DROARING_HOME` points to the DRoaring directory:

```
dmd your_source.d $DROARING_HOME/ext/roaring.o -L-L$DROARING_HOME -L-lroaring -I$DROARING_HOME/source
```

## Example
```d
void main()
{
    import std.stdio : writefln, writeln;
    import roaring.roaring : Bitmap, bitmapOf;

    // create a new roaring bitmap instance
    auto r1 = new Bitmap;

    // add some bits to the bitmap
    r1.add(5);

    // create from an array
    auto ra = bitmapOf([1, 2, 3]);

    // create from a range
    import std.range : iota;
    assert(bitmapOf(0, 1, 2, 3) == bitmapOf(4.iota));
    
    // create a new roaring bitmap instance from some numbers
    auto r2 = bitmapOf(1, 3, 5, 15);

    // check whether a value is contained
    assert(r2.contains(5));
    assert(5 in r2); // r2 contains 5
    assert(99 !in r2); // r2 does not contain 99

    // get minimum and maximum values in a bitmap
    assert(r2.minimum == 1);
    assert(r2.maximum == 15);

    // remove a value from the bitmap
    r2.remove(5);
    assert(!r2.contains(5));
    
    // compute how many bits there are:
    assert(3 == r2.length);

    // check whether a bitmap is subset of another
    const sub = bitmapOf(1, 5);
    const sup = bitmapOf(1, 2, 3, 4, 5, 6);
    assert(sub in sup);

    // iterate on a bitmap
    const r3 = bitmapOf(1, 5, 10, 20);
    ulong s = 0;
    foreach (bit; r3) {
        s += bit;
    }
    assert(s == 36);

    // iterate on a bitmap and index
    foreach(i, bit; r3) {
        writefln("%d: %d", i, bit);
    }

    import roaring.roaring : readBitmap, writeBitmap;
    // serialize the bitmap
    char[] buf = writeBitmap(r3);
    // deserialize from a char array
    const r3Copy = readBitmap(buf);
    assert(r3 == r3Copy);

    // find the intersection of bitmaps
    const r4 = bitmapOf(1, 5, 6);
    const r5 = bitmapOf(1, 2, 3, 4, 5);
    assert((r4 & r5) == bitmapOf(1, 5));
    // find the union of bitmaps
    assert((r4 | r5) == bitmapOf(1, 2, 3, 4, 5, 6));

    const r6 = bitmapOf(0, 10, 20, 30, 40, 50);
    // get the bit for the index
    assert(20 == r6[2]);
    // slice a bitmap
    assert(bitmapOf(30, 40, 50) == r6[3..$]);

    // convert the bitmap to a string
    writeln("Bitmap: ", r6);
    import std.conv : to;
    assert("{0, 10, 20, 30, 40, 50}" == to!string(r6));

    // the bit range!
    import std.algorithm : filter, sum;
    import roaring.roaring : range, BitRange;
    // sum of bits in r6 which are bit % 20==0
    assert(60 == r6.range.filter!(b => b % 20 == 0).sum);

    // if your bitmaps have long runs, you can compress them
    auto r7 = bitmapOf(1000.iota);
    writeln("size before optimize = ", r7.sizeInBytes);
    r7.optimize();
    writeln("size after optimize = ", r7.sizeInBytes);
    
    // copy a bitmap (uses copy-on-write under the hood)
    const r8 = r7.dup;
    assert(r8 == r7);
}
```

## Build

### Using DUB

Using default D compiler:

```
dub build
```

Specifying the D compiler:
```
dub build --compiler=$LDC_HOME/bin/ldc2
```

### Using make

Using default D compiler:

```
make
```

Specifying the D compiler:
```
make DMD=$LDC_HOME/bin/ldc2
```

## Running Tests

```
dub test
```

## License

* `ext/roaring.c` and `ext/roaring.h` were generated from [CRoaring](https://github.com/RoaringBitmap/CRoaring/) source. Copyright 2016 The CRoaring authors. See the [LICENSE](https://github.com/RoaringBitmap/CRoaring/blob/master/LICENSE).

* D Wrapper for CRoaring: Copyright 2018 Yüce Tekol. See the [LICENSE](https://github.com/yuce/droaring/blob/master/LICENSE).
