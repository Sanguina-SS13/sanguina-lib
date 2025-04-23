const std = @import("std");
const bapi = @import("byondapi");
const globals = @import("globals");

const bapi_col = globals.bapi.collision;
const bit = globals.bitmath;
const col = globals.collision;
const core = globals.core;
const types = globals.bapi.types;

const can_pass = @import("can_pass.zig").canPass;
const find_free_space = @import("find_free_space.zig").find_free_space;

pub fn enter_stacked(_mover: bapi.ByondValueRaw, _new_loc: bapi.ByondValueRaw, _old_loc: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const mover = bapi.ByondValue{ .inner = _mover };
    const new_loc = bapi.ByondValue{ .inner = _new_loc };
    const old_loc = bapi.ByondValue{ .inner = _old_loc };
    const sref = types.strRefs;

    const collision_mover = bapi_col.fetch_movable_collision(mover);

    const collision_newloc = bapi_col.fetch_turf_collision(new_loc, true, core.local_alloc);
    defer collision_newloc.deinit();
    const collision_oldloc = bapi_col.fetch_turf_collision(old_loc, true, core.local_alloc);
    defer collision_oldloc.deinit();

    const result = can_pass(core.local_alloc, collision_mover, collision_newloc.items, collision_oldloc.items);
    defer result.bumped.deinit();

    for (result.bumped.items) |bumped| {
        _ = bumped.ref(false).callByID(sref.proc_bumped, &[_]bapi.ByondValueRaw{mover.inner});
    }

    if (result.allowed) {
        if (result.new_collision_bitmask != collision_mover.collision_bitmask)
            bapi_col.update_movable_collision(.{
                .collision_bitmask = result.new_collision_bitmask,
                .flags = collision_mover.flags,
                .ref = mover,
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

    //var byond_list = bapi.ByondValue{ .inner = undefined };
    //_ = mover.callByID(sref.proc_bump, byond_list.writeList(data: []const ByondValueRaw))
    for (result.bumped.items) |collider| {
        _ = collider.ref(false).callByID(sref.proc_bumped, &[_]bapi.ByondValueRaw{mover.inner});
    }
    if (result.floor) |floor| {
        _ = floor.ref(false).callByID(sref.proc_steppedon, &[_]bapi.ByondValueRaw{mover.inner});
    } else {
        // we zfalliiin~
        _ = mover.callByID(sref.proc_zfall, null);
    }
    return bapi.getNull().inner;
}

pub fn get_floor_at(_turf: bapi.ByondValueRaw, _mutable: bapi.ByondValueRaw, _height: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const turf = bapi.ByondValue{ .inner = _turf };
    const mutable = bapi.ByondValue{ .inner = _mutable };
    const height: u7 = @intFromFloat(_height.data.num);

    const floor_refs = bapi_col.fetch_floor_colliders(turf, core.local_alloc);
    defer floor_refs.deinit();

    const checked_bit: u72 = bit.height2bit(height);
    for (floor_refs.items) |maybe_val| {
        if (maybe_val) |val| {
            if (val.collision_bitmask & checked_bit != 0) {
                return val.ref(mutable.isTrue()).inner;
            }
        }
    }
    return bapi.getNull().inner;
}

pub fn get_floor_top(_turf: bapi.ByondValueRaw, _mutable: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const turf = bapi.ByondValue{ .inner = _turf };
    const mutable = bapi.ByondValue{ .inner = _mutable };

    const collision_turf = bapi_col.fetch_floor_colliders(turf, core.local_alloc);
    defer collision_turf.deinit();

    const ret = collision_turf.getLastOrNull();
    if (ret != null) {
        return ret.?.?.ref(mutable.isTrue()).inner;
    }
    return bapi.getNull().inner;
}

pub fn get_floor_below(_mover: bapi.ByondValueRaw, _mutable: bapi.ByondValueRaw, _direct: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const mover: bapi.ByondValue = .{ .inner = _mover };
    const mutable = bapi.ByondValue{ .inner = _mutable };
    const _direct_val: bapi.ByondValue = .{ .inner = _direct };
    const direct = _direct_val.isTrue();
    const sref = types.strRefs;

    const collision_mover = bapi_col.fetch_movable_collision(mover);
    const collision_turf = bapi_col.fetch_floor_colliders(
        bapi.callGlobalByID(sref.proc_get_step, &[_]bapi.ByondValueRaw{
            mover.inner,
            bapi.getNumber(0).inner,
        }),
        core.local_alloc,
    );
    defer collision_turf.deinit();

    var checked_bit = bit.floor_bits(collision_mover.collision_bitmask);
    while (checked_bit != 0) {
        for (collision_turf.items) |maybe_val| {
            if (maybe_val == null)
                continue;
            const val = maybe_val.?;
            if (val.collision_bitmask & checked_bit != 0) {
                return val.ref(mutable.isTrue()).inner;
            }
        }
        if (direct) {
            break;
        }
        checked_bit <<= 1;
    }
    return bapi.getNull().inner;
}
