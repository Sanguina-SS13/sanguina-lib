const std = @import("std");
const bapi = @import("_byondapi.zig");

pub const bitDir = enum(u4) {
    North = (1 << 0),
    South = (1 << 1),
    East = (1 << 2),
    West = (1 << 3),
};

pub const intDir = enum {
    North,
    East,
    South,
    West,
};

pub fn reverse(val: u4) u4 {
    return ((val & 5) << 1) | ((val & 10) >> 1);
}

pub fn cancelOpposite(val: u4) u4 {
    return val & ~(reverse(val));
}

/// Returned bitDir uses source as the reference point.
pub fn coords2dir(source: bapi.ByondXYZ, compared: bapi.ByondXYZ) u4 {
    var ret: u4 = 0;
    const xsign = std.math.sign(compared.inner.x - source.inner.x);
    const ysign = std.math.sign(compared.inner.y - source.inner.y);

    ret |= switch (xsign) {
        -1 => bitDir.West,
        1 => bitDir.East,
    };
    ret |= switch (ysign) {
        -1 => bitDir.South,
        1 => bitDir.North,
    };

    return ret;
}

pub var strRefs: struct {
    // byond inbuilts
    contents: bapi.RefID,
    layer: bapi.RefID,
    plane: bapi.RefID,
    invisibility: bapi.RefID,
    see_invisible: bapi.RefID,
    // floor map
    floor_by_height_index: bapi.RefID,
    turf_bitmask_a: bapi.RefID,
    turf_bitmask_b: bapi.RefID,
    turf_bitmask_c: bapi.RefID,
    // movable collision stuff
    collision_flags: bapi.RefID,
    z_step_size: bapi.RefID,
    movable_bitmask_a: bapi.RefID,
    movable_bitmask_b: bapi.RefID,
    movable_bitmask_c: bapi.RefID,
    // global vars
    glob_floor_type_lookup: bapi.RefID,
    // procs
    proc_text2path: bapi.RefID,
    proc_bump: bapi.RefID,
    proc_bumped: bapi.RefID,
    proc_steppedon: bapi.RefID,
    proc_zfall: bapi.RefID,
    proc_get_step: bapi.RefID,
    proc_istype: bapi.RefID,
} = undefined;

pub var typeLookup: struct {
    @"/turf/stacked": bapi.ByondValue,
} = undefined;

pub var globHolder: bapi.ByondValue = undefined;

pub fn float2flags(T: anytype, f: f32) T {
    return @bitCast(@as(u24, @truncate(@as(u32, @intFromFloat(f)))));
}
