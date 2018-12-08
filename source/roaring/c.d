module roaring.c;

import core.stdc.inttypes: uint8_t, uint16_t, int32_t, uint32_t, uint64_t;

extern(C):

struct roaring_array_t {
    int32_t size;
    int32_t allocation_size;
    void **containers;
    uint16_t *keys;
    uint8_t *typecodes;
}

struct roaring_bitmap_t {
    roaring_array_t high_low_container;
    bool copy_on_write;
}

struct roaring_uint32_iterator_t {
    const roaring_bitmap_t *parent;  // owner
    int32_t container_index;         // point to the current container index
    int32_t in_container_index;  // for bitset and array container, this is out
                                 // index
    int32_t run_index;           // for run container, this points  at the run
    uint32_t in_run_index;  // within a run, this is our index (points at the
                            // end of the current run)

    uint32_t current_value;
    bool has_value;

    const void *container;  // should be:
                     // parent->high_low_container.containers[container_index];
    uint8_t typecode;  // should be:
                       // parent->high_low_container.typecodes[container_index];
    uint32_t highbits;  // should be:
                        // parent->high_low_container.keys[container_index]) <<
                        // 16;
}

extern(C) alias roaring_iterator = bool function(uint32_t value, void* param);

@nogc @safe
void roaring_bitmap_add(roaring_bitmap_t *r, uint32_t x);

/**
 * Add value n_args from pointer vals, faster than repeatedly calling
 * roaring_bitmap_add
 *
 */
void roaring_bitmap_add_many(roaring_bitmap_t *r, size_t n_args, const uint32_t *vals);

/**
 * Computes the intersection between two bitmaps and returns new bitmap. The
 * caller is
 * responsible for memory management.
 *
 */
@nogc @safe
roaring_bitmap_t *roaring_bitmap_and(const roaring_bitmap_t *x1, const roaring_bitmap_t *x2);

/**
 * Inplace version modifies x1, x1 == x2 is allowed
 */
@nogc @safe
void roaring_bitmap_and_inplace(roaring_bitmap_t *x1,
                                const roaring_bitmap_t *x2);

/**
 * Computes the union between two bitmaps and returns new bitmap. The caller is
 * responsible for memory management.
 */
@nogc @safe
roaring_bitmap_t *roaring_bitmap_or(const roaring_bitmap_t *x1, const roaring_bitmap_t *x2);

/**
 * Inplace version of roaring_bitmap_or, modifies x1. TDOO: decide whether x1 ==
 *x2 ok
 *
 */
@nogc @safe
void roaring_bitmap_or_inplace(roaring_bitmap_t *x1,
                               const roaring_bitmap_t *x2);

/**
 * Computes the symmetric difference (xor) between two bitmaps
 * and returns new bitmap. The caller is responsible for memory management.
 */
@nogc @safe
roaring_bitmap_t *roaring_bitmap_xor(const roaring_bitmap_t *x1, const roaring_bitmap_t *x2);

/**
 * Inplace version of roaring_bitmap_xor, modifies x1. x1 != x2.
 *
 */
@nogc @safe
void roaring_bitmap_xor_inplace(roaring_bitmap_t *x1,
                                const roaring_bitmap_t *x2);
/**
 * Computes the  difference (andnot) between two bitmaps
 * and returns new bitmap. The caller is responsible for memory management.
 */
roaring_bitmap_t *roaring_bitmap_andnot(const roaring_bitmap_t *x1,
                                        const roaring_bitmap_t *x2);

/**
 * Inplace version of roaring_bitmap_andnot, modifies x1. x1 != x2.
 *
 */
void roaring_bitmap_andnot_inplace(roaring_bitmap_t *x1,
                                   const roaring_bitmap_t *x2);


@nogc @safe
bool roaring_bitmap_contains(const roaring_bitmap_t *r, uint32_t val) pure;

@nogc
roaring_bitmap_t *roaring_bitmap_create();

@nogc
roaring_bitmap_t *roaring_bitmap_create_with_capacity(uint32_t cap);

/**
 * Return true if all the elements of ra1 are also in ra2.
 */
bool roaring_bitmap_is_subset(const roaring_bitmap_t *ra1, const roaring_bitmap_t *ra2);


/**  use with roaring_bitmap_serialize
* see roaring_bitmap_portable_deserialize if you want a format that's
* compatible with Java and Go implementations
*/
roaring_bitmap_t *roaring_bitmap_deserialize(const void *buf);

/**
 * read a bitmap from a serialized version. This is meant to be compatible with
 * the Java and Go versions. See format specification at
 * https://github.com/RoaringBitmap/RoaringFormatSpec
 * In case of failure, a null pointer is returned.
 * This function is unsafe in the sense that if there is no valid serialized
 * bitmap at the pointer, then many bytes could be read, possibly causing a buffer
 * overflow. For a safer approach,
 * call roaring_bitmap_portable_deserialize_safe.
 */
roaring_bitmap_t *roaring_bitmap_portable_deserialize(const char *buf);

/**
 * read a bitmap from a serialized version in a safe manner (reading up to maxbytes).
 * This is meant to be compatible with
 * the Java and Go versions. See format specification at
 * https://github.com/RoaringBitmap/RoaringFormatSpec
 * In case of failure, a null pointer is returned.
 */
roaring_bitmap_t *roaring_bitmap_portable_deserialize_safe(const char *buf, size_t maxbytes);

/**
 * Check how many bytes would be read (up to maxbytes) at this pointer if there
 * is a bitmap, returns zero if there is no valid bitmap.
 * This is meant to be compatible with
 * the Java and Go versions. See format specification at
 * https://github.com/RoaringBitmap/RoaringFormatSpec
 */
size_t roaring_bitmap_portable_deserialize_size(const char *buf, size_t maxbytes);

/**
 * Return true if the two bitmaps contain the same elements.
 */
bool roaring_bitmap_equals(const roaring_bitmap_t *ra1, const roaring_bitmap_t *ra2);

void roaring_bitmap_free(roaring_bitmap_t *r);
roaring_bitmap_t *roaring_bitmap_from_range(uint64_t min, uint64_t max, uint32_t step);

@nogc @safe
uint64_t roaring_bitmap_get_cardinality(const roaring_bitmap_t *ra) pure;

@nogc @safe
uint32_t roaring_bitmap_maximum(const roaring_bitmap_t *bm) pure;

@nogc @safe
uint32_t roaring_bitmap_minimum(const roaring_bitmap_t *bm) pure;

/**
* roaring_bitmap_rank returns the number of integers that are smaller or equal
* to x.
*/
@nogc @safe
uint64_t roaring_bitmap_rank(const roaring_bitmap_t *bm, uint32_t x) pure;

/**
 * write a bitmap to a char buffer.  The output buffer should refer to at least
 *  roaring_bitmap_portable_size_in_bytes(ra) bytes of allocated memory.
 * This is meant to be compatible with
 * the
 * Java and Go versions. Returns how many bytes were written which should be
 * roaring_bitmap_portable_size_in_bytes(ra).  See format specification at
 * https://github.com/RoaringBitmap/RoaringFormatSpec
 */
size_t roaring_bitmap_portable_serialize(const roaring_bitmap_t *ra, char *buf);

/**
 * How many bytes are required to serialize this bitmap (meant to be compatible
 * with Java and Go versions).  See format specification at
 * https://github.com/RoaringBitmap/RoaringFormatSpec
 */
@nogc @safe
size_t roaring_bitmap_portable_size_in_bytes(const roaring_bitmap_t *ra) pure;

@nogc @safe
void roaring_bitmap_remove(roaring_bitmap_t *r, uint32_t x);

@nogc @safe
bool roaring_bitmap_run_optimize(roaring_bitmap_t *r);

bool roaring_bitmap_select(const roaring_bitmap_t *bm, uint32_t rank, uint32_t *element);

/**
* write the bitmap to an output pointer, this output buffer should refer to
* at least roaring_bitmap_size_in_bytes(ra) allocated bytes.
*
* see roaring_bitmap_portable_serialize if you want a format that's compatible
* with Java and Go implementations
*
* this format has the benefit of being sometimes more space efficient than
* roaring_bitmap_portable_serialize
* e.g., when the data is sparse.
*
* Returns how many bytes were written which should be
* roaring_bitmap_size_in_bytes(ra).
*/
size_t roaring_bitmap_serialize(const roaring_bitmap_t *ra, char *buf);

/**
 * How many bytes are required to serialize this bitmap (NOT compatible
 * with Java and Go versions)
 */
 @nogc @safe
size_t roaring_bitmap_size_in_bytes(const roaring_bitmap_t *ra) pure;

/**
 * Convert the bitmap to an array. Write the output to "ans",
 * caller is responsible to ensure that there is enough memory
 * allocated
 * (e.g., ans = malloc(roaring_bitmap_get_cardinality(mybitmap)
 *   * sizeof(uint32_t)) )
 */
void roaring_bitmap_to_uint32_array(const roaring_bitmap_t *ra, uint32_t *ans);

/**
* Advance the iterator. If there is a new value, then it->has_value is true.
* The new value is in it->current_value. Values are traversed in increasing
* orders. For convenience, returns it->has_value.
*/
@nogc
bool roaring_advance_uint32_iterator(roaring_uint32_iterator_t *it);

/**
* Create an iterator object that can be used to iterate through the
* values. Caller is responsible for calling roaring_free_iterator.
* The iterator is initialized. If there is a  value, then it->has_value is true.
* The first value is in it->current_value. The iterator traverses the values
* in increasing order.
*
* This function calls roaring_init_iterator.
*/
@nogc
roaring_uint32_iterator_t *roaring_create_iterator(const roaring_bitmap_t *ra);

/**
* Free memory following roaring_create_iterator
*/
@nogc
void roaring_free_uint32_iterator(roaring_uint32_iterator_t *it);


/**
* Copies a  bitmap. This does memory allocation. The caller is responsible for
* memory management.
*
*/
@nogc
roaring_bitmap_t *roaring_bitmap_copy(const roaring_bitmap_t *r);

