const std = @import("std");
const zig = @import("../global/core.zig");

const bapi = @import("../byondapi/_byondapi.zig");
const types = @import("../byondapi/types.zig");
const col = @import("../byondapi/collision.zig");
const render = @import("../byondapi/render.zig");

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
    var alloc = zig.local_alloc;
    const sref = types.strRefs;

    const mover: bapi.ByondValue = .{ .inner = _mover };
    const new_loc: bapi.ByondValue = .{ .inner = _new_loc };
    _ = _old_loc;

    const mover_collision = col.fetch_movable_collision(mover);
    const turf_colliders = col.fetch_turf_collision(new_loc, true, alloc);
    defer alloc.free(turf_colliders);

    const DistData = struct {
        distance: u10,
        collider: col.CollisionData,
    };

    const height_mover = @clz(mover_collision.collision_bitmask);
    var floor_or_null: ?DistData = null;

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

    if (floor_or_null == null) {
        // YOU FALLIN INTO THE ABYSS M80
        @branchHint(.unlikely);
        // TODO
        return bapi.getNull().inner;
    }

    const floor = floor_or_null.?;
    const mover_step_size: u10 = @trunc(mover.readVarByID(sref.z_step_size).asNum());
    if (floor.distance == 0) {
        return bapi.getNull().inner;
    }

    if (floor.distance > mover_step_size) {
        mover.callByID(sref.proc_zfall);
    } else if (floor.distance != 0) {
        // dont update if theres no need (dist == 0 if already stepped up (updated) on Enter(), f.e)
        col.update_movable_collision(mover_collision);
    }
}

pub fn enter_stacked(_mover: bapi.ByondValueRaw, _new_loc: bapi.ByondValueRaw, _old_loc: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const sref = types.strRefs;
    const mover: bapi.ByondValue = .{ .inner = _mover };
    const new_loc: bapi.ByondValue = .{ .inner = _new_loc };
    const old_loc: bapi.ByondValue = .{ .inner = _old_loc };

    var alloc = zig.local_alloc;

    const mover_collision = col.fetch_movable_collision(mover);
    if (mover_collision.flags.NOCLIP) {
        @branchHint(.unlikely);
        return bapi.getNumber(1).inner;
    }

    const collision_new = col.fetch_turf_collision(new_loc, true, alloc);
    defer alloc.free(collision_new);
    const collision_old = col.fetch_turf_collision(old_loc, true, alloc);
    defer alloc.free(collision_old);

    // now the actual meat
    var passthroughs = std.ArrayList(col.CollisionData).init(alloc);
    defer alloc.free(passthroughs);

    const mover_step_size: u10 = if (mover_collision.flags.PROHIBIT_HEIGHT_INCREASE) 0 else @trunc(mover.readVarByID(sref.z_step_size).asNum());
    const mover_head = mover_collision.collision_bitmask & -mover_collision.collision_bitmask; // two's compliment funky

    var bumped: ?col.CollisionData = null;
    var success: bool = false;
    outer: for (0..@min(mover_step_size, @ctz(mover_head)) + 1) |i| {
        if (i != 0) {
            // check if we're not bumping into a ceiling
            for (collision_old) |collider| {
                if (mover_head & collider == 0)
                    continue;
                if (collider.flags.PASS_THROUGH) {
                    if (std.mem.indexOfScalar(col.CollisionData, passthroughs.items, collider))
                        continue;
                    passthroughs.append(collider);
                    continue;
                }
                success = false;
                break :outer;
            }
        }

        var blocked_movement = false;
        for (collision_new) |collider| {
            if (std.meta.eql(collider.ref.inner, mover.inner)) {
                @branchHint(.unlikely);
                continue; // dont collide with yourself kthx
            }
            if (collider.collision_bitmask & mover_collision.collision_bitmask == 0)
                continue;

            if (collider.flags.PASS_THROUGH) {
                @branchHint(.unlikely);
                passthroughs.append(collider);
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

        mover_collision.collision_bitmask >> i;
        success = true;
        break;
    }

    if (success) {
        for (passthroughs.items) |collider| {
            const args = alloc.alloc(bapi.ByondValue, 1) catch unreachable;
            defer alloc.free(args);

            switch (collider.ref.inner.type) {
                .Obj, .Mob => collider.ref.callByID(sref.proc_bumped, args),
                _ => collider.ref.callSrcless("Bumped", args),
            }
        }
        return bapi.getNumber(1).inner;
    } else {
        if (bumped) |collider| {
            const args = alloc.alloc(bapi.ByondValue, 1) catch unreachable;
            defer alloc.free(args);

            switch (collider.ref.inner.type) {
                .Obj, .Mob => collider.ref.callByID(sref.proc_bumped, args),
                _ => collider.ref.callSrcless("Bumped", args),
            }
        }
        return bapi.getNumber(0).inner;
    }
}

pub fn get_floor_at(_turf: bapi.ByondValueRaw, _height: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const turf = bapi.ByondValue{ .inner = _turf };

    const collision_turf = col.fetch_turf_collision(turf, false, zig.local_alloc);
    defer zig.local_alloc.free(collision_turf);

    const checked_bit: u72 = ((std.math.maxInt(u72) >> 1) + 1) >> (@as(u24, @intFromFloat(_height.data.num)) - 1);
    for (collision_turf.items) |val| {
        if (val.collision_bitmask & checked_bit) {
            return val.ref.inner;
        }
    }
    return bapi.getNull().inner;
}

pub fn get_floor_top(_turf: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const turf = bapi.ByondValue{ .inner = _turf };

    const collision_turf = col.fetch_turf_collision(turf, false, zig.local_alloc);
    defer zig.local_alloc.free(collision_turf);

    return collision_turf.getLast().ref.inner;
}

pub fn get_floor_below(_mover: bapi.ByondValueRaw, _direct: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const mover: bapi.ByondValue = .{_mover};
    const _direct_val: bapi.ByondValue = .{_direct};
    const direct = _direct_val.isTrue();
    const sref = types.strRefs;

    const collision_mover = col.fetch_movable_collision(mover);
    const collision_turf = col.fetch_turf_collision(
        bapi.callGlobalByID(sref.proc_get_step, .{
            mover,
            bapi.getNumber(0),
        }),
        zig.local_alloc,
    );
    var checked_bit = (collision_mover.collision_bitmask << 1) ^ collision_mover.collision_bitmask;

    while (checked_bit != 0) {
        for (collision_turf.items) |val| {
            if (val.collision_bitmask & checked_bit != 0) {
                return val.ref.inner;
            }
        }
        if (direct) {
            break;
        }
        checked_bit <<= 1;
    }
    return bapi.getNull().inner;
}
