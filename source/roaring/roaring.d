
module roaring.roaring;

import roaring.c;

Roaring bitmapOf(const uint[] args ...)
{
    return Roaring.fromArray(args);
}

Roaring bitmapOf(const uint[] bits)
{
    return Roaring.fromArray(bits);
}

Roaring bitmapOf(T)(T rng)
{
    auto r = new Roaring;
    foreach (bit; rng) r.add(bit);
    return r;
}

Roaring readBitmap(const char[] buf)
{
    return Roaring.read(buf);
}

char[] writeBitmap(const Roaring r)
{
    return r.write();
}

BitRange range(const Roaring r)
{
    return new BitRange(r.bitmap);
}

class BitRange
{
    @nogc @property @safe
    bool empty() const pure
    {
        return !this.it.has_value;
    }

    @nogc @property @safe
    uint front() const pure
    {
        return this.it.current_value;
    }

    @nogc
    void popFront()
    {
        if (it.has_value) roaring_advance_uint32_iterator(this.it);
    }

    @nogc
    private this(const roaring_bitmap_t *bmp)
    {
        this.it = roaring_create_iterator(bmp);
    }

    @nogc
    private ~this()
    {
        if (this.it) roaring_free_uint32_iterator(this.it);
    }

    private roaring_uint32_iterator_t *it;
}

class Roaring
{
    /// Creates an empty bitmap
    this()
    {
        this(roaring_bitmap_create());
    }
    
    ~this()
    {
        roaring_bitmap_free(this.bitmap);
        this.bitmap = null;
    }

    /** Creates an empty bitmap with a predefined capacity
        PARAMS
            uint cap: The predefined capacity
    */
    this(const uint cap)
    {
        this(roaring_bitmap_create_with_capacity(cap));
    }

    private this(roaring_bitmap_t *r)
    {
        this.bitmap = r;
    }

    private static Roaring fromArray(const uint[] bits)
    {
        Roaring r = new Roaring(cast(uint)bits.length);
        roaring_bitmap_add_many(r.bitmap, bits.length, bits.ptr);
        return r;
    }

    private static Roaring fromRange(const ulong min, const ulong max, const uint step)
    {
        auto rr = roaring_bitmap_from_range(min, max, step);
        return new Roaring(rr);
    }

    private static Roaring read(const char[] buf)
    {
        import core.exception : OutOfMemoryError;
        auto rr = roaring_bitmap_portable_deserialize_safe(buf.ptr, buf.length);
        if (!rr) {
            throw new OutOfMemoryError;
        }
        return new Roaring(rr);
    }

    private char[] write() const
    {
        char[] buf = new char[sizeInBytes];
        const size = roaring_bitmap_portable_serialize(this.bitmap, buf.ptr);
        return buf[0..size];
    }

    @nogc @property @safe
    uint length() const pure
    {
        return cast(uint)roaring_bitmap_get_cardinality(this.bitmap);
    }

    @nogc @property @safe
    void copyOnWrite(bool enable)
    {
        this.bitmap.copy_on_write = enable;
    }

    uint[] toArray() const
    {
        uint[] a = new uint[length];
        roaring_bitmap_to_uint32_array(this.bitmap, a.ptr);
        return a[];
    }

    @nogc @safe
    void add(const uint x)
    {
        roaring_bitmap_add(this.bitmap, x);
    }

    /**
     * Remove value x
     *
     */
    @nogc @safe
    void remove(const uint x)
    {
        roaring_bitmap_remove(this.bitmap, x);
    }

    /**
     * Check if value x is present
     */
    @nogc @safe
    bool contains(const uint x) const pure
    {
        return roaring_bitmap_contains(this.bitmap, x);
    }

    /**
     * Return the largest value (if not empty)
     *
     */
    @nogc @property @safe
    uint maximum() const pure
    {
        return roaring_bitmap_maximum(this.bitmap);
    }

    /**
    * Return the smallest value (if not empty)
    *
    */
    @nogc @property @safe
    uint minimum() const pure
    {
        return roaring_bitmap_minimum(this.bitmap);
    }

    @nogc @property @safe
    size_t sizeInBytes() const pure
    {
        return roaring_bitmap_portable_size_in_bytes(this.bitmap);
    }

    /**
    * Returns the number of integers that are smaller or equal to x.
    */
    @nogc @safe
    ulong rank(const uint rank) const pure
    {
        return roaring_bitmap_rank(this.bitmap, rank);
    }

    @nogc @safe
    bool optimize()
    {
        return roaring_bitmap_run_optimize(this.bitmap);
    }

    int opApply(int delegate(ref uint value) dg) const
    {
        const bmp = this.bitmap;
        auto it = roaring_create_iterator(bmp);
        int dgReturn = 0;
        while (it.has_value) {
            dgReturn = dg(it.current_value);
            if (dgReturn) break;
            roaring_advance_uint32_iterator(it);
        }
        roaring_free_uint32_iterator(it);
        return dgReturn;
    }

    // TODO: un-duplicate this method with ^^^
    int opApply(int delegate(ref uint index, ref uint value) dg) const
    {
        const bmp = this.bitmap;
        auto it = roaring_create_iterator(bmp);
        int dgReturn = 0;
        uint index = 0;
        while (it.has_value) {
            dgReturn = dg(index, it.current_value);
            if (dgReturn) break;
            index += 1;
            roaring_advance_uint32_iterator(it);
        }
        roaring_free_uint32_iterator(it);
        return dgReturn;
    }

    Roaring opBinary(const string op)(const Roaring b) const
    if (op == "&" || op == "|")
    {
        roaring_bitmap_t *result;
        static if (op == "&") result = roaring_bitmap_and(this.bitmap, b.bitmap);
        else static if (op == "|") result = roaring_bitmap_or(this.bitmap, b.bitmap);
        else static assert(0, "Operator " ~ op ~ " not implemented.");
        
        return new Roaring(result);
    }

    bool opBinaryRight(const string op)(const uint x) const
    if (op == "in")
    {
        static if (op == "in") return roaring_bitmap_contains(this.bitmap, x);
        else static assert(0, "Operator " ~ op ~ " not implemented.");
    }

    bool opBinaryRight(const string op)(const Roaring b) const
    if (op == "in")
    {
        static if (op == "in") return roaring_bitmap_is_subset(b.bitmap, this.bitmap);
        else static assert(0, "Operator " ~ op ~ " not implemented.");
    }

    @nogc @property @safe
    uint opDollar() const pure
    {
        return length;
    }

    uint opIndex(uint rank) const
    {
        import core.exception : RangeError;
        uint v;
        if (!roaring_bitmap_select(this.bitmap, rank, &v)) {
            throw new RangeError;
        }
        return v;
    }

    Roaring opSlice(int start, int end) const
    {
        import core.exception : RangeError;
        if (start < 0 || start >= opDollar) {
            throw new RangeError;
        }
        Roaring r = new Roaring;
        foreach (i, bit; this) {
            if (i < start) continue;
            if (i >= end) break;
            r.add(this[i]);
        }
        return r;
    }

    override bool opEquals(Object b) const
    {
        import std.stdio : writeln;
        if (this is b) return true;
        if (b is null) return false;
        if (typeid(this) == typeid(b)) {
            return roaring_bitmap_equals(this.bitmap, (cast(Roaring)b).bitmap);
        }
        return false;
    }

    void opOpAssign(const string op)(const uint x)
    if (op == "|" || op == "-")
    {
        static if (op == "|") roaring_bitmap_add(this.bitmap, x);
        else static if (op == "-") roaring_bitmap_remove(this.bitmap, x);
    }

    void toString(scope void delegate(const(char)[]) sink) const
    {
        import std.format : format;
        import std.range : enumerate;
        sink("{");
        foreach (i, bit; this) {
            if (i == 0) sink(format("%d", bit));
            else sink(format(", %d", bit));
        }
        sink("}");
    }

    private roaring_bitmap_t* bitmap;
}

unittest
{
    void test_add_remove()
    {
        // create new empty bitmap
        Roaring r1 = new Roaring;
        // add values
        foreach (i; 100 .. 1000) {
            r1.add(i);
        }
        // check whether a value is contained
        assert(r1.contains(500));
        assert(500 in r1);
        assert(109999 !in r1);

        // check the number of bits
        assert(r1.length == 900);

        r1 |= 9999;
        assert(r1.contains(9999));
        assert(r1.length == 901);

        r1.remove(150);
        assert(!r1.contains(150));

        r1 -= 555;
        assert(!r1.contains(555));
    }

    void test_optimize(bool copyOnWrite)
    {
        auto r1 = bitmapOf(5, 1, 2, 3, 5, 6);
        r1.copyOnWrite = copyOnWrite;
        //check optimization
        auto size1 = r1.sizeInBytes;
        r1.optimize;
        assert(r1.sizeInBytes < size1);
    }

    void test_bitmapOf()
    {
        const r = bitmapOf(5, 1, 2, 3, 5, 6);
        assert(r.contains(5));
        assert(r.length == 5);
        assert(bitmapOf([1, 2, 3, 5, 6]) == r);

        import std.range : iota;
        assert(bitmapOf(0, 1, 2, 3) == bitmapOf(4.iota));
    }

    void test_minimum_maximum()
    {
        const r = bitmapOf(5, 1, 2, 3, 5, 6);
        assert(r.minimum == 1);
        assert(r.maximum == 6);

        const r2 = bitmapOf(100, 0, uint.max);
        assert(r2.minimum == 0);
        assert(r2.maximum == uint.max);
    }

    void test_rank()
    {
        const r = bitmapOf(5, 1, 2, 3, 5, 6);
        assert(r.rank(4) == 3);
    }

    void test_toArray()
    {
        const r = bitmapOf(5, 1, 2, 3, 5, 6);
        uint[] a = r.toArray();
        assert(a.length == 5);
    }

    void test_equals()
    {
        const r1 = Roaring.fromRange(10, 20, 3);
        const r2 = Roaring.fromArray([10, 13, 16, 19]);
        assert(r1 == r2);

        const r3 = Roaring.fromArray([10]);
        assert(r1 != r3);

        assert(r1 != new Object);
    }

    void test_union()
    {
        const r1 = bitmapOf(5, 1, 2, 3, 5, 6);
        const r2 = bitmapOf(6, 7, 8);
        assert((r1 | r2) == bitmapOf(1, 2, 3, 5, 6, 7, 8));
    }

    void test_intersect()
    {
        const r1 = bitmapOf(5, 1, 2, 3, 5, 6);
        const r2 = bitmapOf(6, 7, 8);
        assert((r1 & r2) == bitmapOf(6));
    }

    void test_write_read()
    {
        import core.exception : OutOfMemoryError;
        const r1 = bitmapOf(5, 1, 2, 3, 5, 6);
        char[] buf = writeBitmap(r1);
        const r2 = readBitmap(buf);
        assert(r1 == r2);
        try {
            buf.length = 0;
            readBitmap(buf) || assert(false);
        }
        catch (OutOfMemoryError e) {
            // pass
        }
    }

    void test_subset()
    {
        const sub = bitmapOf(1, 5);
        const sup = bitmapOf(1, 2, 3, 4, 5, 6);
        assert(sub in sup);
    }

    void test_iterate()
    {
        const bitmap = bitmapOf(5, 1, 2, 3, 5, 6);
        ulong sum;
        foreach (bit; bitmap) {
            sum += bit;
        }
        assert(sum == 17);
    }

    void test_toString()
    {
        import std.conv : to;
        const bitmap = bitmapOf(5, 1, 2, 3, 5, 6);
        assert("{1, 2, 3, 5, 6}" == to!string(bitmap));
    }

    void test_index()
    {
        import core.exception : RangeError;
        const bitmap = bitmapOf(5, 1, 2, 3, 5, 6);
        assert(5 == bitmap[3]);
        // accessing an index > cardinality(set) throws a RangeError
        try {
            bitmap[999] || assert(false);
        }
        catch (RangeError e) {
            // pass
        }       
    }

    void test_slice()
    {
        import core.exception : RangeError;
        const bitmap = bitmapOf(5, 1, 2, 3, 5, 6);
        assert(bitmapOf(3, 5, 6) == bitmap[2..$]);
    }

    void test_sliceInvalidStart()
    {
        import core.exception : RangeError;
        const bitmap = bitmapOf(5, 1, 2, 3, 5, 6);
        // accessing an index < 0 throws a RangeError
        try {
            bitmap[-1..$] || assert(false);
        }
        catch (RangeError e) {
            // pass
        }
    }
    
    void test_sliceInvalidStart2()
    {
        import core.exception : RangeError;
        const bitmap = bitmapOf(5, 1, 2, 3, 5, 6);
        // accessing an index > $ throws a RangeError
        try {
            bitmap[$..$] || assert(false);
        }
        catch (RangeError e) {
            // pass
        }
    }

    void test_bitRange()
    {
        import std.algorithm : filter, sum;
        assert(6 == bitmapOf(1, 2, 3, 4, 5).range.filter!(a => a % 2 == 0).sum);
    }    

    void test_readme()
    {
        import std.stdio : writefln, writeln;
        import roaring.roaring : Roaring, bitmapOf;

        // create a new roaring bitmap instance
        auto r1 = new Roaring;

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
        writeln("size before optimize = ", r7.sizeInBytes);
   }

    test_add_remove();
    test_bitmapOf();
    test_bitRange();
    test_equals();
    test_index();
    test_intersect();
    test_iterate();
    test_minimum_maximum();
    test_optimize(true);
    test_optimize(false);
    test_rank();
    test_slice();
    test_sliceInvalidStart();
    test_sliceInvalidStart2();
    test_subset();
    test_toArray();
    test_toString();
    test_union();
    test_write_read();

    test_readme();
}