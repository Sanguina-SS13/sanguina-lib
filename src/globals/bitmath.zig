// The "fuck im too tired to brain" file.

/// Last set bit in X.
pub fn head_bit(X: anytype) @TypeOf(X) {
    return X & -%X; // two's compliment funky
}

/// Bit BEFORE the first bit set. If there's holes in the mask, it similarly includes a floor bit per each run.
pub fn floor_bits(X: anytype) @TypeOf(X) {
    return (X << 1) ^ X;
}

pub fn height2bit(height: u7) u72 {
    const shift: u7 = 72 - 1 - height;
    // Cast 1 into T, shift it into place, return:
    return @as(u72, 1) << shift;
}

// For runs in X which are guaranteed to be contiguous.
// pub fn floor_bit_contiguous(X: anytype) @TypeOf(X) {
//     return (X << 1) ^ X;
// }
