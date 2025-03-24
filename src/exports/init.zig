const std = @import("std");
const bapi = @import("../byondapi/_byondapi.zig");
const types = @import("../byondapi/types.zig");
const zig = @import("../defines/zig.zig");

export fn init() callconv(.c) bapi.ByondValueRaw {
    // in case of failure, you STILL need to call deinit()
    var ret: bapi.ByondValue = undefined;

    zig.alloc = .init();
    zig.rand = .init();

    types.strRefs = .{
        // byond inbuilts
        .contents = bapi.getStrIdOrCreate("contents"),
        .layer = bapi.getStrIdOrCreate("layer"),
        // turf collision shit
        .floor_by_height_index = bapi.getStrIdOrCreate("floor_by_height_index"),
        .turf_bitmask_a = bapi.getStrIdOrCreate("floor_border_bitmask_upper"),
        .turf_bitmask_b = bapi.getStrIdOrCreate("floor_border_bitmask"),
        .turf_bitmask_c = bapi.getStrIdOrCreate("floor_border_bitmask_lower"),
        // movable collision shit
        .z_step_size = bapi.getStrIdOrCreate("z_step_size"),
        .collision_flags = bapi.getStrIdOrCreate("collision_flags"),
        .movable_bitmask_a = bapi.getStrIdOrCreate("collision_bitmask_lower"),
        .movable_bitmask_b = bapi.getStrIdOrCreate("collision_bitmask"),
        .movable_bitmask_c = bapi.getStrIdOrCreate("collision_bitmask_upper"),
        // procs
        .proc_text2path = bapi.getStrIdOrCreate("text2path"),
        .proc_bump = bapi.getStrIdOrCreate("Bump"),
        .proc_blocked = bapi.getStrIdOrCreate("Blocked"),
    };

    var temp: bapi.ByondValue = undefined;
    var t2p_id = types.strRefs.proc_text2path;
    types.typeLookup = .{
        .@"/turf/stacked" = bapi.callGlobalByID(t2p_id, temp.writeStr("/turf/stacked")),
    };

    return ret.clear().inner;
}

export fn deinit() callconv(.c) bapi.ByondValueRaw {
    return std.mem.zeroes(bapi.ByondValueRaw);
}
