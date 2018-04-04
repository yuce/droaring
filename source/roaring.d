
module roaring.roaring;

import roaring.c;

class Roaring {
    /// Creates an empty bitmap
    this() {
        this(roaring_bitmap_create());
    }
    
    ~this() {
        roaring_bitmap_free(this.roaring);
        this.roaring = null;
    }

    /** Creates an empty bitmap with a predefined capacity
        PARAMS
            uint cap: The predefined capacity
    */
    this(const uint cap) {
        this(roaring_bitmap_create_with_capacity(cap));
    }

    private this(roaring_bitmap_t *r) {
        this.roaring = r;
    }

    static Roaring bitmapOf(const uint[] args ...) {
        return Roaring.fromArray(args);
    }

    static Roaring fromArray(const uint[] bits) {
        Roaring r = new Roaring(cast(uint)bits.length);
        roaring_bitmap_add_many(r.roaring, bits.length, bits.ptr);
        return r;
    }

    static Roaring fromRange(const ulong min, const ulong max, const uint step) {
        auto rr = roaring_bitmap_from_range(min, max, step);
        return new Roaring(rr);
    }

    static Roaring read(const char[] buf) {
        auto rr = roaring_bitmap_portable_deserialize_safe(buf.ptr, buf.length);
        if (!rr) {
            // TODO: raise an exception
            return null;
        }
        return new Roaring(rr);
    }

    @property
    ulong cardinality() const {
        return roaring_bitmap_get_cardinality(this.roaring);
    }
    @property
    void copyOnWrite(bool enable) {
        this.roaring.copy_on_write = enable;
    }

    uint[] toArray() const {
        uint[] a = new uint[this.cardinality];
        roaring_bitmap_to_uint32_array(this.roaring, a.ptr);
        return a[];
    }

    void add(const uint x) {
        roaring_bitmap_add(this.roaring, x);
    }

    /**
     * Remove value x
     *
     */
    void remove(const uint x) {
        roaring_bitmap_remove(this.roaring, x);
    }

    /**
     * Check if value x is present
     */
    bool contains(const uint x) const {
        return roaring_bitmap_contains(this.roaring, x);
    }

    /**
     * Return the largest value (if not empty)
     *
     */
    @property
    uint maximum() const {
        return roaring_bitmap_maximum(this.roaring);
    }

    /**
    * Return the smallest value (if not empty)
    *
    */
    @property
    uint minimum() const {
        return roaring_bitmap_minimum(this.roaring);
    }

    @property
    size_t sizeInBytes() const {
        return roaring_bitmap_size_in_bytes(this.roaring);
    }

    void printf() const {
        roaring_bitmap_printf(this.roaring);
    }

    /**
    * Returns the number of integers that are smaller or equal to x.
    */
    ulong rank(const uint rank) const {
        return roaring_bitmap_rank(this.roaring, rank);
    }

    bool select(const uint rank, out uint elem) const {
        return roaring_bitmap_select(this.roaring, rank, &elem);
    }

    bool optimize() {
        return roaring_bitmap_run_optimize(this.roaring);
    }

    char[] write(const bool portable = true) const
    {
        char[] buf;
        ulong size;
        if (portable) {
            buf = new char[roaring_bitmap_portable_size_in_bytes(this.roaring)];
            size = roaring_bitmap_portable_serialize(this.roaring, buf.ptr);
        }
        else {
            buf = new char[roaring_bitmap_size_in_bytes(this.roaring)];
            size = roaring_bitmap_serialize(this.roaring, buf.ptr);
        }
        return buf[0..size];
    }

    void opOpAssign(const string op)(const uint x)
    if (op == "|" || op == "-")
    {
        static if (op == "|") roaring_bitmap_add(this.roaring, x);
        else static if (op == "-") roaring_bitmap_remove(this.roaring, x);
    }

    Roaring opBinary(const string op)(const Roaring b) const
    if (op == "&" || op == "|")
    {
        roaring_bitmap_t *result;
        static if (op == "&") result = roaring_bitmap_and(this.roaring, b.roaring);
        else static if (op == "|") result = roaring_bitmap_or(this.roaring, b.roaring);
        else static assert(0, "Operator " ~ op ~ " not implemented.");
        
        return new Roaring(result);
    }

    override bool opEquals(const Object b) {
        import std.stdio : writeln;
        if (this is b) return true;
        if (b is null) return false;
        if (typeid(this) == typeid(b)) {
            return roaring_bitmap_equals(this.roaring, (cast(Roaring)b).roaring);
        }
        return false;
    }

    private roaring_bitmap_t* roaring;
}

unittest {
    void test_add_remove() {
        // create new empty bitmap
        Roaring r1 = new Roaring;
        // add values
        foreach (i; 100 .. 1000) {
            r1.add(i);
        }
        // check whether a value is contained
        assert(r1.contains(500));
        // check the number of bits
        assert(r1.cardinality == 900);

        r1 |= 9999;
        assert(r1.contains(9999));
        assert(r1.cardinality == 901);

        r1.remove(150);
        assert(!r1.contains(150));

        r1 -= 555;
        assert(!r1.contains(555));
    }

    void test_optimize(bool copyOnWrite) {
        auto r1 = Roaring.bitmapOf(5, 1, 2, 3, 5, 6);
        r1.copyOnWrite = copyOnWrite;
        //check optimization
        auto size1 = r1.sizeInBytes;
        r1.optimize;
        assert(r1.sizeInBytes < size1);
    }

    void test_bitmapOf() {
        const r = Roaring.bitmapOf(5, 1, 2, 3, 5, 6);
        assert(r.contains(5));
        assert(r.cardinality == 5);
    }

    void test_select() {
        const r = Roaring.bitmapOf(5, 1, 2, 3, 5, 6);
        uint el;
        assert(r.select(3, el));
        assert(el == 5);
    }

    void test_minimum_maximum() {
        const r = Roaring.bitmapOf(5, 1, 2, 3, 5, 6);
        assert(r.minimum == 1);
        assert(r.maximum == 6);

        const r2 = Roaring.bitmapOf(100, 0, uint.max);
        assert(r2.minimum == 0);
        assert(r2.maximum == uint.max);
    }

    void test_rank() {
        const r = Roaring.bitmapOf(5, 1, 2, 3, 5, 6);
        assert(r.rank(4) == 3);
    }

    void test_toArray() {
        const r = Roaring.bitmapOf(5, 1, 2, 3, 5, 6);
        uint[] a = r.toArray();
        assert(a.length == 5);
    }

    void test_equals() {
        const r1 = Roaring.fromRange(10, 20, 3);
        const r2 = Roaring.fromArray([10, 13, 16, 19]);
        assert(r1 == r2);

        const r3 = Roaring.fromArray([10]);
        assert(r1 != r3);
    }

    void test_union() {
        const r1 = Roaring.bitmapOf(5, 1, 2, 3, 5, 6);
        const r2 = Roaring.bitmapOf(6, 7, 8);
        const r3 = r1 | r2;
        assert(r3 == Roaring.bitmapOf(1, 2, 3, 5, 6, 7, 8));
    }

    void test_intersect() {
        const r1 = Roaring.bitmapOf(5, 1, 2, 3, 5, 6);
        const r2 = Roaring.bitmapOf(6, 7, 8);
        const r3 = r1 & r2;
        assert(r3 == Roaring.bitmapOf(6));
    }

    void test_write_read() {
        const r1 = Roaring.bitmapOf(5, 1, 2, 3, 5, 6);
        auto buf = r1.write();
        const r2 = Roaring.read(buf);
        assert(r1 == r2);
    }
    
    test_add_remove();
    test_bitmapOf();
    test_equals();
    test_intersect();
    test_minimum_maximum();
    test_optimize(true);
    test_optimize(false);
    test_rank();
    test_select();
    test_toArray();
    test_union();
    test_write_read();
}