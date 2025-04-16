const std = @import("std");
const bapi = @import("byondapi");

pub const bitDir = packed struct(u4) {
    North: u1 = 0,
    South: u1 = 0,
    East: u1 = 0,
    West: u1 = 0,

    pub fn reverse(val: bitDir) bitDir {
        return .{
            .North = val.South,
            .South = val.North,
            .East = val.West,
            .West = val.East,
        };
        // return ((num & 5) << 1) | ((num & 10) >> 1);
    }

    pub fn cancelOpposite(val: bitDir) bitDir {
        return .{
            .North = val.North & !val.South,
            .South = val.South & !val.North,
            .East = val.East & !val.West,
            .West = val.West & !val.East,
        };
        //return num & ~(reverse(num));
    }
};

pub const intDir = enum(u2) {
    North,
    East,
    South,
    West,
};

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
