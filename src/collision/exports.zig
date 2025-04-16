const std = @import("std");
const bapi = @import("byondapi");
const globals = @import("globals");

const bapi_col = globals.bapi.collision;
const col = globals.collision;
const core = globals.core;
const types = globals.bapi.types;

const can_pass = @import("can_pass.zig").can_pass;
const find_free_space = @import("find_free_space.zig").find_free_space;

pub fn enter_stacked(_mover: bapi.ByondValueRaw, _new_loc: bapi.ByondValueRaw, _old_loc: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const mover = bapi.ByondValue{ .inner = _mover };
    const new_loc = bapi.ByondValue{ .inner = _new_loc };
    const old_loc = bapi.ByondValue{ .inner = _old_loc };
    const sref = types.strRefs;

    const collision_mover = blk: {
        const temp = bapi_col.fetch_movable_collision(mover);
        break :blk col.CollisionDataExpanded{
            .collision_bitmask = temp.collision_bitmask,
            .flags = temp.flags,
            .ref = temp.ref,
            .step_size = if (temp.flags.PROHIBIT_HEIGHT_INCREASE) 0 else @intFromFloat(temp.ref.readVarByID(sref.z_step_size).asNum()),
        };
    };

    const collision_newloc = bapi_col.fetch_turf_collision(new_loc, true, core.local_alloc);
    defer collision_newloc.deinit();
    const collision_oldloc = bapi_col.fetch_turf_collision(old_loc, true, core.local_alloc);
    defer collision_oldloc.deinit();

    const result = can_pass(core.local_alloc, collision_mover, collision_newloc.items, collision_oldloc.items);
    defer result.bumped.deinit();

    for (result.bumped.items) |bumped| {
        @compileError("figure out how to deal with no srcless");
        _ = bumped.ref.callByID(sref.proc_bumped, &[_]bapi.ByondValueRaw{mover.inner});
    }

    if (result.allowed) {
        if (result.new_collision_bitmask != collision_mover.collision_bitmask)
            bapi_col.update_movable_collision(.{
                .collision_bitmask = result.new_collision_bitmask,
                .flags = collision_mover.flags,
                .ref = _mover,
            });
        return bapi.getNumber(1).inner;
    }

    return bapi.getNumber(0).inner;
}

pub fn entered_stacked(_mover: bapi.ByondValueRaw, _new_loc: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const mover = bapi.ByondValue{ .inner = _mover };
    const new_loc = bapi.ByondValue{ .inner = _new_loc };
    const sref = types.strRefs;

    const collision_mover = bapi_col.fetch_movable_collision(mover);

    const collision_newloc = bapi_col.fetch_turf_collision(new_loc, true, core.local_alloc);
    defer collision_newloc.deinit();

    const maybe_result = find_free_space(
        core.local_alloc,
        .{
            .collision_bitmask = collision_mover.collision_bitmask,
            .flags = collision_mover.flags,
            .ref = collision_mover.ref,
            .step_size = if (collision_mover.flags.PROHIBIT_HEIGHT_INCREASE) 0 else @intFromFloat(mover.readVarByID(sref.z_step_size).asNum()),
        },
        collision_newloc.items,
        .DownUp,
    );
    if (maybe_result == null) {
        // well we've already entered.. uhhh.
        @branchHint(.unlikely);
        return bapi.getNull().inner;
    }

    const result = maybe_result.?;
    defer result.bumped.deinit();

    if (result.new_col_mask != collision_mover.collision_bitmask) {
        _ = bapi_col.update_movable_collision(collision_mover);
    }
    for (result.bumped.items) |collider| {
        @compileError("figure out how to deal with no srcless");
        _ = collider.ref.callByID(sref.proc_bumped, &[_]bapi.ByondValueRaw{mover.inner});
    }
    if (result.floor) |floor| {
        @compileError("figure out how to deal with no srcless");
        _ = floor.ref.callByID(sref.proc_steppedon, &[_]bapi.ByondValueRaw{mover.inner});
    } else {
        // we zfalliiin~
        _ = mover.callByID(sref.proc_zfall, null);
    }
}
