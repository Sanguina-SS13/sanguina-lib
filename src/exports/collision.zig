const std = @import("std");
const core = @import("../global/core.zig");

const bapi = @import("../byondapi/_byondapi.zig");
const types = @import("../byondapi/types.zig");
const col = @import("../byondapi/collision.zig");
const render = @import("../byondapi/render.zig");
const bit = @import("../helpers/bitmath.zig");

// shamelessly ripped from chatgpt
fn dist_above_floor(floor: col.CollisionData, mover: col.CollisionData) u7 {
    const floor_mask = floor.collision_bitmask;
    const mover_mask = mover.collision_bitmask;
    std.debug.assert(mover_mask != 0);

    // Determine b's leftmost set bit (most significant bit set)
    const bLeft: u7 = @as(u7, @typeInfo(u72).int.bits - 1) - @clz(mover_mask);

    // Isolate from 'a' only those bits that are strictly to the left of b's leftmost set bit.
    // The mask (~0 << (bLeft + 1)) has all bits set from position (bLeft+1) upward.
    const candidate: u72 = floor_mask & (~@as(u72, 0) << @intCast(bLeft + 1));

    // The rightmost set bit in 'candidate' (i.e. the boundary of the relevant region in a)
    const aBoundary: u7 = @ctz(candidate);

    // The gap is the number of zeros between that bit and b's leftmost set bit.
    return aBoundary - bLeft - 1;
}

pub fn entered_stacked(_mover: bapi.ByondValueRaw, _new_loc: bapi.ByondValueRaw, _old_loc: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const alloc = core.local_alloc;
    const sref = types.strRefs;

    const mover: bapi.ByondValue = .{ .inner = _mover };
    const new_loc: bapi.ByondValue = .{ .inner = _new_loc };
    const old_loc: bapi.ByondValue = .{ .inner = _old_loc };

    var mover_collision = col.fetch_movable_collision(mover);
    const turf_colliders = col.fetch_turf_collision(new_loc, true, alloc);
    defer turf_colliders.deinit();

    const DistData = struct {
        distance: u10,
        collider: col.CollisionData,
    };
    var floor_or_null: ?DistData = null;

    if (bapi.callGlobalByID(sref.proc_istype, &[_]bapi.ByondValueRaw{ old_loc.inner, types.typeLookup.@"/turf/stacked".inner }).inner.data.num != 0) {
        // we're coming from a fellow stackee, try and pretend this is actual 3D
        const height_mover = @clz(mover_collision.collision_bitmask);

        for (turf_colliders.items) |collider| {
            if (@clz(collider.collision_bitmask) > height_mover)
                continue; // above us

            const collider_distance = dist_above_floor(collider, mover_collision);
            if (floor_or_null == null or floor_or_null.?.distance > collider_distance) {
                floor_or_null = .{
                    .distance = collider_distance,
                    .collider = collider,
                };
            }
        }
    } else {
        // fuck it just shove him wherever
        mover_collision.collision_bitmask >>= @ctz(mover_collision.collision_bitmask);
        outer: while (@clz(mover_collision.collision_bitmask) > 0) {
            const floor_bit = bit.floor_bit_contiguous(mover_collision.collision_bitmask);

            for (turf_colliders.items) |collider| {
                if (collider.collision_bitmask & floor_bit != 0) {
                    floor_or_null = .{
                        .distance = 0,
                        .collider = collider,
                    };
                    break :outer;
                }
            }
        }
    }

    if (floor_or_null == null) {
        // YOU FALLIN INTO THE ABYSS M80
        @branchHint(.unlikely);
        // TODO
        return bapi.getNull().inner;
    }

    const floor = floor_or_null.?;
    const mover_step_size: u7 = @intFromFloat(mover.readVarByID(sref.z_step_size).asNum());
    if (floor.distance == 0) {
        return bapi.getNull().inner;
    }

    if (floor.distance > mover_step_size) {
        _ = mover.callByID(sref.proc_zfall, null);
    } else if (floor.distance != 0) {
        // dont update if theres no need (dist == 0 if already stepped up (updated) on Enter(), f.e)
        col.update_movable_collision(mover_collision);
    }
    return bapi.getNull().inner;
}

pub fn enter_stacked(_mover: bapi.ByondValueRaw, _new_loc: bapi.ByondValueRaw, _old_loc: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const sref = types.strRefs;
    const mover: bapi.ByondValue = .{ .inner = _mover };
    const new_loc: bapi.ByondValue = .{ .inner = _new_loc };
    const old_loc: bapi.ByondValue = .{ .inner = _old_loc };

    const alloc = core.local_alloc;

    var mover_collision = col.fetch_movable_collision(mover);
    if (mover_collision.flags.NOCLIP) {
        @branchHint(.unlikely);
        return bapi.getNumber(1).inner;
    }

    const collision_new = col.fetch_turf_collision(new_loc, true, alloc);
    defer collision_new.deinit();
    const collision_old = col.fetch_turf_collision(old_loc, true, alloc);
    defer collision_old.deinit();

    // now the actual meat
    var passthroughs = std.ArrayList(col.CollisionData).initCapacity(alloc, 4) catch unreachable;
    defer passthroughs.deinit();

    const mover_step_size: u7 = if (mover_collision.flags.PROHIBIT_HEIGHT_INCREASE) 0 else @intFromFloat(mover.readVarByID(sref.z_step_size).asNum());
    const mover_head = bit.head_bit(mover_collision.collision_bitmask);

    var bumped: ?col.CollisionData = null;
    var success: bool = false;
    outer: for (0..@min(mover_step_size, @ctz(mover_head)) + 1) |i| {
        if (i != 0) {
            // check if we're not bumping into a ceiling
            inner: for (collision_old.items) |collider| {
                if (mover_head & collider.collision_bitmask == 0)
                    continue;
                if (collider.flags.PASS_THROUGH) {
                    for (passthroughs.items) |passer| {
                        if (passer.ref.inner.data.ref == collider.ref.inner.data.ref)
                            continue :inner;
                    }
                    passthroughs.append(collider) catch unreachable;
                    continue;
                }
                success = false;
                break :outer;
            }
        }

        var blocked_movement = false;
        for (collision_new.items) |collider| {
            if (collider.ref.inner.type == mover.inner.type and collider.ref.inner.data.ref == mover.inner.data.ref) {
                @branchHint(.unlikely);
                continue; // dont collide with yourself kthx
            }
            if (collider.collision_bitmask & mover_collision.collision_bitmask == 0)
                continue;

            if (collider.flags.PASS_THROUGH) {
                @branchHint(.unlikely);
                passthroughs.append(collider) catch unreachable;
                continue; // we handle these later
            }
            if (collider.flags.BLOCK_NO_BUMP) {
                blocked_movement = true;
                continue; // scan for any actual bumpers
            }
            bumped = collider;
            continue :outer;
        }
        if (blocked_movement)
            continue;

        mover_collision.collision_bitmask >>= @intCast(i);
        success = true;
        break;
    }

    if (success) {
        for (passthroughs.items) |collider| {
            const args = [_]bapi.ByondValueRaw{mover.inner};
            _ = switch (collider.ref.inner.type) {
                .Obj, .Mob => collider.ref.callByID(sref.proc_bumped, &args),
                else => collider.ref.callSrcless("Bumped", &args),
            };
        }
        return bapi.getNumber(1).inner;
    } else {
        if (bumped) |collider| {
            const args = [_]bapi.ByondValueRaw{mover.inner};
            _ = switch (collider.ref.inner.type) {
                .Obj, .Mob => collider.ref.callByID(sref.proc_bumped, &args),
                else => collider.ref.callSrcless("Bumped", &args),
            };
        }
        return bapi.getNumber(0).inner;
    }
}

pub fn get_floor_at(_turf: bapi.ByondValueRaw, _mutable: bapi.ByondValueRaw, _height: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const turf = bapi.ByondValue{ .inner = _turf };
    const mutable = bapi.ByondValue{ .inner = _mutable };

    const floor_refs = col.fetch_floor_colliders(turf, core.local_alloc);
    defer floor_refs.deinit();

    const checked_bit: u72 = @as(u72, (std.math.maxInt(u72) >> 1) + 1) >> @truncate(@as(u24, @intFromFloat(_height.data.num)) - 1);
    for (floor_refs.items, 0..) |maybe_val, i| {
        if (maybe_val) |val| {
            if (val.collision_bitmask & checked_bit != 0) {
                return get_floor_by_index(turf, @intCast(i), mutable.isTrue()).?.inner;
            }
        }
    }
    return bapi.getNull().inner;
}

pub fn get_floor_top(_turf: bapi.ByondValueRaw, _mutable: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const turf = bapi.ByondValue{ .inner = _turf };
    const mutable = bapi.ByondValue{ .inner = _mutable };

    const collision_turf = col.fetch_floor_colliders(turf, core.local_alloc);
    defer collision_turf.deinit();

    const ret = get_floor_by_index(turf, @intCast(collision_turf.items.len), mutable.isTrue());
    if (ret) |val| {
        return val.inner;
    }
    return bapi.getNull().inner;
}

pub fn get_floor_below(_mover: bapi.ByondValueRaw, _mutable: bapi.ByondValueRaw, _direct: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const mover: bapi.ByondValue = .{ .inner = _mover };
    const mutable = bapi.ByondValue{ .inner = _mutable };
    const _direct_val: bapi.ByondValue = .{ .inner = _direct };
    const direct = _direct_val.isTrue();
    const sref = types.strRefs;

    const collision_mover = col.fetch_movable_collision(mover);
    const collision_turf = col.fetch_floor_colliders(
        bapi.callGlobalByID(sref.proc_get_step, &[_]bapi.ByondValueRaw{
            mover.inner,
            bapi.getNumber(0).inner,
        }),
        core.local_alloc,
    );
    defer collision_turf.deinit();

    var checked_bit = (collision_mover.collision_bitmask << 1) ^ collision_mover.collision_bitmask;
    while (checked_bit != 0) {
        for (collision_turf.items, 0..) |maybe_val, i| {
            if (maybe_val == null)
                continue;
            const val = maybe_val.?;
            if (val.collision_bitmask & checked_bit != 0) {
                return get_floor_by_index(val.ref, @intCast(i), mutable.isTrue()).?.inner;
            }
        }
        if (direct) {
            break;
        }
        checked_bit <<= 1;
    }
    return bapi.getNull().inner;
}

pub fn get_floor_by_index(turf: bapi.ByondValue, index: u7, mutable: bool) ?bapi.ByondValue {
    const sref = types.strRefs;
    const ref_list = turf.readVarByID(types.strRefs.floor_by_height_index);
    const arr_floors = ref_list.asList(core.local_alloc);
    defer core.local_alloc.free(arr_floors);

    const arr_entry = arr_floors[index];
    return switch (arr_entry.inner.type) {
        .Null => null,
        .Datum => arr_entry, // already modified, return that
        .DatumTypepath => {
            if (mutable) {
                const new_ref = bapi.new(arr_entry, null);
                ref_list.writeAt(bapi.getNumber(@floatFromInt(index)), new_ref);
                return new_ref;
            } else {
                return types.globHolder.readVarByID(sref.glob_floor_type_lookup).at(arr_entry);
            }
        },
        else => {
            @branchHint(.cold);
            const msg = std.mem.concatWithSentinel(core.local_alloc, u8, &[_][]const u8{ "get_floor_by_index() called with an invalid value (toString: ", arr_entry.toString(core.local_alloc), ")" }, 0) catch unreachable;
            bapi.crashMsg(msg);
        },
    };
}
