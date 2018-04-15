
module roaring.roaring;

import roaring.c;

Bitmap bitmapOf(const uint[] args ...)
{
    pragma(inline, true);
    return Bitmap.fromArray(args);
}

Bitmap bitmapOf(const uint[] bits)
{
    pragma(inline, true);
    return Bitmap.fromArray(bits);
}

Bitmap bitmapOf(T)(T rng)
{
    auto r = new Bitmap;
    foreach (bit; rng) r.add(bit);
    return r;
}

unittest
{
    import std.range : iota;
    import std.conv : to;
    const r1 = bitmapOf(0, 1, 2, 3, 4);
    const r2 = bitmapOf([0, 1, 2, 3, 4]);
    const r3 = bitmapOf(5.iota);
    assert("{0, 1, 2, 3, 4}" == to!string(r1));
    assert((r1 == r2) && (r1 == r3));
}

Bitmap64 bitmap64Of(const ulong[] args...)
{
    pragma(inline, true);
    return bitmap64Of(args);
}

Bitmap64 bitmap64Of(const ulong[] args)
{
    auto b = new Bitmap64;
    foreach (arg; args) b.add(arg);
    return b;
}

unittest
{
    const b = bitmap64Of(1, 2, 3);
    assert(b.length == 3);
    assert(bitmap64Of(1, 2^^40) == bitmap64Of([1, 2^^40]));
}

Bitmap readBitmap(const char[] buf)
{
    return Bitmap.read(buf);
}

char[] writeBitmap(const Bitmap r)
{
    return r.write();
}

unittest
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

BitRange range(const Bitmap r)
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

unittest
{
    import std.algorithm : filter, sum;
    assert(6 == bitmapOf(1, 2, 3, 4, 5).range.filter!(a => a % 2 == 0).sum);
}    



class Bitmap
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

    private static Bitmap fromArray(const uint[] bits)
    {
        Bitmap r = new Bitmap(cast(uint)bits.length);
        roaring_bitmap_add_many(r.bitmap, bits.length, bits.ptr);
        return r;
    }

    private static Bitmap fromRange(const ulong min, const ulong max, const uint step)
    {
        auto rr = roaring_bitmap_from_range(min, max, step);
        return new Bitmap(rr);
    }

    private static Bitmap read(const char[] buf)
    {
        import core.exception : OutOfMemoryError;
        auto rr = roaring_bitmap_portable_deserialize_safe(buf.ptr, buf.length);
        if (!rr) {
            throw new OutOfMemoryError;
        }
        return new Bitmap(rr);
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

    @nogc @property @safe
    bool copyOnWrite() const pure
    {
        return this.bitmap.copy_on_write;
    }

    unittest
    {
        Bitmap r = new Bitmap;
        r.copyOnWrite = true;
        assert(r.copyOnWrite == true);
    }

    uint[] toArray() const
    {
        uint[] a = new uint[length];
        roaring_bitmap_to_uint32_array(this.bitmap, a.ptr);
        return a[];
    }

    unittest
    {
        const r = bitmapOf(5, 1, 2, 3, 5, 6);
        uint[] a = r.toArray;
        assert(a.length == 5);
    }

    @nogc @safe
    void add(const uint x)
    {
        roaring_bitmap_add(this.bitmap, x);
    }

    unittest
    {
        Bitmap r = new Bitmap;
        r.add(5);
        assert(5 in r);
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

    unittest
    {
        Bitmap r = bitmapOf(5);
        r.remove(5);
        assert(5 !in r);
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

    unittest
    {
        const r2 = bitmapOf(100, 10, uint.max);
        assert(r2.minimum == 10);
        assert(r2.maximum == uint.max);
    }    

    @nogc @property @safe
    size_t sizeInBytes() const pure
    {
        return roaring_bitmap_portable_size_in_bytes(this.bitmap);
    }

    unittest
    {
        assert(bitmapOf(5).sizeInBytes > 4);
    }

    /**
    * Returns the number of integers that are smaller or equal to x.
    */
    @nogc @safe
    ulong rank(const uint rank) const pure
    {
        return roaring_bitmap_rank(this.bitmap, rank);
    }

    unittest
    {
        const r = bitmapOf(5, 1, 2, 3, 5, 6);
        assert(r.rank(4) == 3);
    }

    @nogc @safe
    bool optimize()
    {
        return roaring_bitmap_run_optimize(this.bitmap);
    }

    unittest
    {
        auto r1 = bitmapOf(5, 1, 2, 3, 5, 6);
        r1.copyOnWrite = true;
        //check optimization
        auto size1 = r1.sizeInBytes;
        r1.optimize;
        assert(r1.sizeInBytes < size1);
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

    unittest
    {
        const bitmap = bitmapOf(5, 1, 2, 3, 5, 6);
        ulong sum;
        foreach (bit; bitmap) {
            sum += bit;
        }
        assert(sum == 17);
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

    unittest
    {
        const bitmap = bitmapOf(5, 1, 2, 3, 5, 6);
        ulong bitSum;
        int iSum;
        foreach (i, bit; bitmap) {
            bitSum += bit;
            iSum += i;
        }
        assert(bitSum == 17);
        assert(iSum == 10);
    }

    Bitmap opBinary(const string op)(const Bitmap b) const
    if (op == "&" || op == "|" || op == "^")
    {
        roaring_bitmap_t *result;
        static if (op == "&") result = roaring_bitmap_and(this.bitmap, b.bitmap);
        else static if (op == "|") result = roaring_bitmap_or(this.bitmap, b.bitmap);
        else static if (op == "^") result = roaring_bitmap_xor(this.bitmap, b.bitmap);
        else static assert(0, "Operator " ~ op ~ " not implemented.");
        
        return new Bitmap(result);
    }

    unittest
    {
        const r1 = bitmapOf(5, 1, 2, 3, 5, 6);
        const r2 = bitmapOf(6, 7, 8);
        assert((r1 | r2) == bitmapOf(1, 2, 3, 5, 6, 7, 8));
        assert((r1 & r2) == bitmapOf(6));
        assert((r1 ^ r2) == bitmapOf(1, 2, 3, 5, 7, 8));
    }

    @nogc @safe
    bool opBinaryRight(const string op)(const uint x) const
    if (op == "in")
    {
        static if (op == "in") return roaring_bitmap_contains(this.bitmap, x);
        else static assert(0, "Operator " ~ op ~ " not implemented.");
    }

    unittest
    {
        import std.range : iota;
        Bitmap r1 = bitmapOf(iota(100, 1000));
        assert(500 in r1);
    }

    bool opBinaryRight(const string op)(const Bitmap b) const
    if (op == "in")
    {
        static if (op == "in") return roaring_bitmap_is_subset(b.bitmap, this.bitmap);
        else static assert(0, "Operator " ~ op ~ " not implemented.");
    }

    unittest
    {
        import std.range : iota;
        Bitmap r1 = bitmapOf(iota(100, 1000));
        Bitmap r2 = bitmapOf(iota(200, 400));
        assert(r2 in r1);
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

    unittest
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

    Bitmap opSlice(int start, int end) const
    {
        import core.exception : RangeError;
        if (start < 0 || start >= opDollar) {
            throw new RangeError;
        }
        Bitmap r = new Bitmap;
        foreach (i, bit; this) {
            if (i < start) continue;
            if (i >= end) break;
            r.add(this[i]);
        }
        return r;
    }

    @nogc @property @safe
    uint opDollar() const pure
    {
        return length;
    }

    unittest
    {
        import core.exception : RangeError;
        const bitmap = bitmapOf(5, 1, 2, 3, 5, 6);
        assert(bitmapOf(3, 5, 6) == bitmap[2..$]);

        import core.exception : RangeError;
        // accessing an index < 0 throws a RangeError
        try {
            bitmap[-1..$] || assert(false);
        }
        catch (RangeError e) {
            // pass
        }

        import core.exception : RangeError;
        // accessing an index > $ throws a RangeError
        try {
            bitmap[$..$] || assert(false);
        }
        catch (RangeError e) {
            // pass
        }
    }

    override bool opEquals(Object b) const
    {
        if (this is b) return true;
        if (b is null) return false;
        if (typeid(this) == typeid(b)) {
            return roaring_bitmap_equals(this.bitmap, (cast(Bitmap)b).bitmap);
        }
        return false;
    }

    unittest
    {
        const r1 = Bitmap.fromRange(10, 20, 3);
        const r2 = Bitmap.fromArray([10, 13, 16, 19]);
        assert(r1 == r2);

        const r3 = Bitmap.fromArray([10]);
        assert(r1 != r3);

        assert(r1 != new Object);
    }

    void opOpAssign(const string op)(const uint x)
    if (op == "|" || op == "-")
    {
        static if (op == "|") roaring_bitmap_add(this.bitmap, x);
        else static if (op == "-") roaring_bitmap_remove(this.bitmap, x);
    }

    unittest
    {
        Bitmap r1 = new Bitmap;
        r1 |= 500;
        assert(500 in r1);
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

    unittest
    {
        import std.conv : to;
        const bitmap = bitmapOf(5, 1, 2, 3, 5, 6);
        assert("{1, 2, 3, 5, 6}" == to!string(bitmap));
    }    

    private roaring_bitmap_t* bitmap;
}

@nogc @safe
private uint indexOf(const ulong x) pure
{
    pragma(inline, true);
    return cast(uint)(x >> 32);
}

@nogc @safe
private uint lowOf(const ulong x) pure
{
    pragma(inline, true);
    return cast(uint)x;
}

@nogc @safe
private ulong valueOf(const uint index, const uint low) pure
{
    pragma(inline, true);
    return (cast(ulong)index << 32) + low;
}

unittest
{
    import std.stdio : writeln;
    ulong x = cast(ulong)uint.max + 2;
    writeln("x = ", x);
    writeln("index(x) = ", indexOf(x));
    writeln("lowOf(x) = ", lowOf(x));
    writeln("valueOf(x) = ", valueOf(indexOf(x), lowOf(x)));
    // assert(indexOf(x) == 1);
    // assert(lowOf(x) == 1);
    assert(valueOf(indexOf(x), lowOf(x)) == x);
}


class Bitmap64
{
    @nogc @property
    ulong length() const pure
    {
        ulong result = 0;
        foreach (bmp; this.bitmaps.byValue) {
            result += bmp.length;
        }
        return result;
    }

    /**
     * Return the largest value (if not empty)
     *
     */
    @nogc @property @safe
    ulong maximum() const pure
    {
        ulong result = 0;
        foreach (index, bmp; this.bitmaps) {
            const m = valueOf(index, bmp.maximum);
            if (m > result) result = m;
        }
        return  result;
    }

    /**
    * Return the smallest value (if not empty)
    *
    */
    @nogc @property @safe
    ulong minimum() const pure
    {
        ulong result = ulong.max;
        foreach (index, bmp; this.bitmaps) {
            const m = valueOf(index, bmp.minimum);
            if (m < result) result = m;
        }
        return  result;
    }

    unittest
    {
        const r2 = bitmap64Of(100, ulong.max);
        assert(r2.minimum == 100);
        assert(r2.maximum == ulong.max);
    }    

    @nogc @property @safe
    void copyOnWrite(bool enable)
    {
        if (enable == this.copyOnWrite_) return;
        this.copyOnWrite_ = enable;
        foreach (bmp; this.bitmaps.byValue) {
            bmp.bitmap.copy_on_write = enable;
        }
    }

    @nogc @property @safe
    bool copyOnWrite() const
    {
        return this.copyOnWrite_;
    }    

    void add(const ulong x)
    {
        ensureBitmap(indexOf(x)).add(lowOf(x));
    }

    bool contains(const ulong x) const
    {
        const index = indexOf(x);
        if (index !in this.bitmaps) {
            return false;
        }
        return lowOf(x) in this.bitmaps[index];
    }

    @nogc @safe
    bool optimize()
    {
        auto result = false;
        foreach (bmp; this.bitmaps.byValue) {
            result |= bmp.optimize;
        }
        return result;
    }

    unittest
    {
        auto r1 = bitmap64Of(5, 1, 2, 3, 5, 6);
        r1.copyOnWrite = true;
        //check optimization
        auto size1 = r1.sizeInBytes;
        r1.optimize;
        assert(r1.sizeInBytes < size1);
    }    

    @nogc @property @safe
    size_t sizeInBytes() const pure
    {
        size_t result = 0;
        foreach (bmp; this.bitmaps.byValue) {
            result += bmp.sizeInBytes;
        }
        return result;
    }

    unittest
    {
        assert(bitmap64Of(5).sizeInBytes == bitmapOf(5).sizeInBytes);
        assert(bitmap64Of(5, 2^^40).sizeInBytes > bitmapOf(5).sizeInBytes);
    }

    @safe
    bool opBinaryRight(const string op)(const long x) const
    if (op == "in")
    {
        static if (op == "in") {
           const index = indexOf(x);
            if (index !in this.bitmaps) {
                return false;
            }            
            return lowOf(x) in this.bitmaps[index];
        }
        else static assert(0, "Operator " ~ op ~ " not implemented.");
    }

    override bool opEquals(Object b) const
    {
        if (this is b) return true;
        if (b is null) return false;
        if (typeid(this) == typeid(b)) {
            const cb = cast(Bitmap64)b;
            return this.bitmaps == cb.bitmaps;
        }
        return false;
    }    

    private Bitmap ensureBitmap(const uint index)
    {
        if (index !in this.bitmaps) {
            auto bmp = new Bitmap;
            bmp.copyOnWrite = this.copyOnWrite;
            this.bitmaps[index] = bmp;
            return bmp;
        }
        return this.bitmaps[index];
    }
    
    private Bitmap[uint] bitmaps;
    private bool copyOnWrite_ = false;
}

unittest
{
    auto b = new Bitmap64;
    b.add(2^^40);
    assert(2^^40 in b);
    b.add(5);
    assert(b.length == 2);
}

unittest
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
}
