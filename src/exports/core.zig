const std = @import("std");
const bapi = @import("../byondapi/_byondapi.zig");
const types = @import("../byondapi/types.zig");
const zig = @import("../global/core.zig");
const collision = @import("../byondapi/collision.zig");
const world = @import("../byondapi/world.zig");

pub fn init() callconv(.c) bapi.ByondValueRaw {
    // in case of failure, you STILL need to call deinit()
    var temp: bapi.ByondValue = undefined;

    const seed = 420;

    zig.rand = .init(seed);

    // type caching
    types.strRefs = .{
        // byond inbuilts
        .contents = temp.writeStr("contents").incRef().asRef(),
        .layer = temp.writeStr("layer").incRef().asRef(),
        .plane = temp.writeStr("plane").incRef().asRef(),
        .invisibility = temp.writeStr("invisibility").incRef().asRef(),
        .see_invisible = temp.writeStr("see_invisible").incRef().asRef(),
        // turf collision shit
        .floor_by_height_index = temp.writeStr("floor_by_height_index").incRef().asRef(),
        .turf_bitmask_a = temp.writeStr("floor_border_bitmask_upper").incRef().asRef(),
        .turf_bitmask_b = temp.writeStr("floor_border_bitmask").incRef().asRef(),
        .turf_bitmask_c = temp.writeStr("floor_border_bitmask_lower").incRef().asRef(),
        // movable collision shit
        .z_step_size = temp.writeStr("z_step_size").incRef().asRef(),
        .collision_flags = temp.writeStr("collision_flags").incRef().asRef(),
        .movable_bitmask_a = temp.writeStr("collision_bitmask_lower").incRef().asRef(),
        .movable_bitmask_b = temp.writeStr("collision_bitmask").incRef().asRef(),
        .movable_bitmask_c = temp.writeStr("collision_bitmask_upper").incRef().asRef(),
        // glob vars
        .glob_floor_type_lookup = temp.writeStr("floor_type_lookup").incRef().asRef(),
        // procs
        .proc_text2path = temp.writeStr("text2path").incRef().asRef(),
        .proc_bump = temp.writeStr("Bump").incRef().asRef(),
        .proc_bumped = temp.writeStr("Bumped").incRef().asRef(),
        .proc_steppedon = temp.writeStr("SteppedOn").incRef().asRef(),
        .proc_zfall = temp.writeStr("ZFall").incRef().asRef(),
        // not-ideals
        .proc_get_step = temp.writeStr("_get_step").incRef().asRef(),
        .proc_istype = temp.writeStr("_istype").incRef().asRef(),
    };
    types.typeLookup = .{
        // assume that typepath refs cant gc
        .@"/turf/stacked" = bapi.callGlobalByID(types.strRefs.proc_text2path, &[_]bapi.ByondValueRaw{temp.writeStr("/turf/stacked").inner}),
    };
    // fetch GLOB.. ugly, i know.
    types.globHolder = bapi.callGlobal("sanlib_get_glob_holder", null);

    // collision
    //collision.collision_map = .init(zig.global_alloc) catch unreachable;
    //for (collision.collision_map) |value| {}

    return bapi.getNull().inner;
}

pub fn deinit() callconv(.c) bapi.ByondValueRaw {
    // yes, we are leaking the ref strings. does anyone care?
    // only times this will be called is either right before world.Reboot() or a second init() - and in that case these will be reused anyways

    // lets clean up everything else tho
    // var col_iter = collision.collision_map.valueIterator();
    // while (col_iter.next()) |val|
    //     val.collision_data.deinit();
    // collision.collision_map.deinit();

    return bapi.getNull().inner;
}
