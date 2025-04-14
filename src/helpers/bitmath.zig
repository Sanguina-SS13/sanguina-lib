// The "fuck im too tired to brain" file.

/// Last set bit in X.
pub fn head_bit(X: anytype) @TypeOf(X) {
    return X & -%X; // two's compliment funky
}

/// Bit BEFORE the first bit set.
pub fn floor_bit(X: anytype) @TypeOf(X) {
    @compileError("unimplemented");
}

/// For runs in X which are guaranteed to be contiguous.
pub fn floor_bit_contiguous(X: anytype) @TypeOf(X) {
    return (X << 1) ^ X;
}
