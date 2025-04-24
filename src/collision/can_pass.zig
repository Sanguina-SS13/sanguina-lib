const std = @import("std");
const bapi = @import("byondapi");
const globals = @import("globals");

const col = globals.collision;
const bit = globals.bitmath;

const CanPassMovableResult = struct {
    passable: bool,
    bumped: bool,
};
fn canPassMovable(mover_col: col.MovableCollider, bumped: col.ColliderData) CanPassMovableResult {
    const ret = CanPassMovableResult;

    if (bumped.eql(col.ColliderData{ .Movable = mover_col })) {
        @branchHint(.unlikely);
        return ret{ .bumped = false, .passable = true }; // dont collide with yourself kthx
    }
    if (mover_col.collision_bitmask & bumped.bitmask() == 0)
        // no collision
        return ret{ .bumped = false, .passable = true };

    // we collide, but can we pass
    if (bumped.flags().PASS_THROUGH) {
        @branchHint(.unlikely);
        return ret{ .bumped = true, .passable = true };
    }
    // do we bump?
    if (bumped.flags().BLOCK_NO_BUMP) {
        @branchHint(.unlikely);
        return ret{ .bumped = false, .passable = false };
    }
    // regular ass blocker
    return ret{ .bumped = true, .passable = false };
}

const CanPassResult = struct {
    allowed: bool,
    new_collision_bitmask: u72,
    bumped: std.ArrayList(col.ColliderData),
};
pub fn canPass(alloc: std.mem.Allocator, mover_col: col.MovableCollider, newloc_cols: []const col.ColliderData, oldloc_cols: []const col.ColliderData) CanPassResult {
    var ret = CanPassResult{
        .allowed = false,
        .new_collision_bitmask = mover_col.collision_bitmask,
        .bumped = std.ArrayList(col.ColliderData).init(alloc),
    };
    if (mover_col.flags.NOCLIP) {
        @branchHint(.unlikely);
        ret.allowed = true;
        return ret;
    }

    var passthroughs = std.ArrayList(col.ColliderData).initCapacity(alloc, 4) catch unreachable;
    defer passthroughs.deinit();

    const mover_head = bit.head_bit(mover_col.collision_bitmask);

    var bumped: ?col.ColliderData = null;
    outer: for (0..@min(mover_col.step_size, @ctz(mover_head)) + 1) |i| {
        if (i != 0) {
            // check if we're not bumping into a ceiling
            inner: for (oldloc_cols) |collider| {
                const cp = canPassMovable(mover_col, collider);
                if (!cp.passable) {
                    continue :outer;
                }

                if (cp.bumped) {
                    for (passthroughs.items) |passer| {
                        if (passer.eql(collider))
                            continue :inner;
                    }
                    passthroughs.append(collider) catch unreachable;
                    continue;
                }
            }
        }

        var blocked_movement = false;
        inner: for (newloc_cols) |collider| {
            const cp = canPassMovable(mover_col, collider);
            if (cp.passable) {
                if (cp.bumped) {
                    // dont append us multiple times..
                    for (passthroughs.items) |passer| {
                        if (passer.eql(collider))
                            continue :inner;
                    }
                    passthroughs.append(collider) catch unreachable;
                    continue;
                }
            } else {
                if (cp.bumped) {
                    bumped = collider;
                    continue :outer;
                }
                blocked_movement = true;
                continue;
            }
        }
        if (blocked_movement)
            continue;

        ret.new_collision_bitmask = mover_col.collision_bitmask >> @intCast(i);
        ret.allowed = true;
        break;
    }
    return ret;
}

test "canPass leveled floor" {
    const alloc = std.testing.allocator;

    const movable_col_mask = 0b00000000_11100000_00000000;
    const new_loc_col_mask = 0b11111111_00000000_00000000;

    const mover_col = col.MovableCollider{
        .collision_bitmask = movable_col_mask,
        .ref = bapi.getNumber(1),
        .step_size = 1,
    };
    const newloc_col = [1]col.ColliderData{.{ .Floor = .{
        .collision_bitmask = new_loc_col_mask,
        .turf_ref = undefined,
        .floor_ref = undefined,
        .height_index = undefined,
        .floor_by_height_index = undefined,
    } }};

    const result = canPass(alloc, mover_col, &newloc_col, &[_]col.ColliderData{});
    defer result.bumped.deinit();

    try std.testing.expect(result.allowed);
    try std.testing.expectEqual(result.new_collision_bitmask, mover_col.collision_bitmask);
    try std.testing.expectEqual(result.bumped.items.len, 0);
}

test "canPass step up" {
    const alloc = std.testing.allocator;

    const movable_col_mask = 0b00000000_11100000_00000000;
    const newloc_col_mask_ = 0b11111111_10000000_00000000;

    const mover_col = col.MovableCollider{
        .collision_bitmask = movable_col_mask,
        .ref = bapi.getNumber(1),
        .step_size = 1,
    };
    const newloc_col: [1]col.ColliderData = .{.{ .Floor = .{
        .collision_bitmask = newloc_col_mask_,
        .turf_ref = undefined,
        .floor_ref = undefined,
        .height_index = undefined,
        .floor_by_height_index = undefined,
    } }};

    const result = canPass(alloc, mover_col, &newloc_col, &[_]col.ColliderData{});
    defer result.bumped.deinit();

    try std.testing.expect(result.allowed);
    try std.testing.expectEqual(result.new_collision_bitmask, mover_col.collision_bitmask >> 1);
    try std.testing.expectEqual(result.bumped.items.len, 0);
}

test "canPass step down" {
    const alloc = std.testing.allocator;

    const movable_col_mask = 0b00000000_11100000_00000000;
    const newloc_col_mask_ = 0b11111110_00000000_00000000;

    const mover_col = col.MovableCollider{
        .collision_bitmask = movable_col_mask,
        .ref = bapi.getNumber(1),
        .step_size = 1,
    };
    const newloc_col = [1]col.ColliderData{.{ .Floor = .{
        .collision_bitmask = newloc_col_mask_,
        .turf_ref = undefined,
        .floor_ref = undefined,
        .height_index = undefined,
        .floor_by_height_index = undefined,
    } }};

    const result = canPass(alloc, mover_col, &newloc_col, &[_]col.ColliderData{});
    defer result.bumped.deinit();

    try std.testing.expect(result.allowed);
    try std.testing.expectEqual(result.new_collision_bitmask, mover_col.collision_bitmask); // we dont handle this stuff
    try std.testing.expectEqual(result.bumped.items.len, 0);
}

test "canPass blocked by newloc" {
    const alloc = std.testing.allocator;

    const movable_col_mask_ = 0b00000000_11100000_00000000;
    const newloc_col_mask_a = 0b11111111_11000000_00000000;
    const newloc_col_mask_b = 0b00000000_00011111_00000000;

    const mover_col = col.MovableCollider{
        .collision_bitmask = movable_col_mask_,
        .ref = bapi.getNumber(1),
        .step_size = 1,
    };
    const newloc_col = [2]col.ColliderData{ .{ .Floor = .{
        .collision_bitmask = newloc_col_mask_a,
        .turf_ref = undefined,
        .floor_ref = undefined,
        .height_index = undefined,
        .floor_by_height_index = undefined,
    } }, .{ .Floor = .{
        .collision_bitmask = newloc_col_mask_b,
        .turf_ref = undefined,
        .floor_ref = undefined,
        .height_index = undefined,
        .floor_by_height_index = undefined,
    } } };

    const result = canPass(alloc, mover_col, &newloc_col, &[_]col.ColliderData{});
    defer result.bumped.deinit();

    try std.testing.expect(!result.allowed);
    try std.testing.expectEqual(result.new_collision_bitmask, mover_col.collision_bitmask);

    try std.testing.expectEqual(result.bumped.items.len, newloc_col.len);
    try for (result.bumped.items, newloc_col) |x, y| {
        if (!x.eql(y))
            break error.TestExpectedEqual;
    };
}

test "canPass blocked by oldloc" {
    const alloc = std.testing.allocator;

    const movable_col_mask = 0b00000000_11100000_00000000;
    const newloc_col_mask_ = 0b11111111_10000000_00000000;
    const oldloc_col_mask_ = 0b00000000_00011111_00000000;

    const mover_col = col.MovableCollider{
        .collision_bitmask = movable_col_mask,
        .ref = bapi.getNumber(1),
        .step_size = 1,
    };
    const newloc_col = [1]col.ColliderData{.{ .Floor = .{
        .collision_bitmask = newloc_col_mask_,
        .turf_ref = undefined,
        .floor_ref = undefined,
        .height_index = undefined,
        .floor_by_height_index = undefined,
    } }};
    const oldloc_col = [1]col.ColliderData{.{ .Floor = .{
        .collision_bitmask = oldloc_col_mask_,
        .turf_ref = undefined,
        .floor_ref = undefined,
        .height_index = undefined,
        .floor_by_height_index = undefined,
    } }};

    const result = canPass(alloc, mover_col, &newloc_col, &oldloc_col);
    defer result.bumped.deinit();

    try std.testing.expect(!result.allowed);
    try std.testing.expectEqual(result.new_collision_bitmask, mover_col.collision_bitmask);

    try std.testing.expectEqual(result.bumped.items.len, newloc_col.len);
    try for (result.bumped.items, newloc_col) |x, y| {
        if (!x.eql(y))
            break error.TestExpectedEqual;
    };
}

test "canPass wacky newloc" {
    const alloc = std.testing.allocator;

    const movable_col_mask = 0b00000000_11100000_00000000;
    const new_loc_col_mask = 0b10101010_10101010_10101010;

    const mover_col = col.MovableCollider{
        .collision_bitmask = movable_col_mask,
        .ref = bapi.getNumber(1),
        .step_size = 1,
    };
    const newloc_col = [1]col.ColliderData{.{ .Floor = .{
        .collision_bitmask = new_loc_col_mask,
        .turf_ref = undefined,
        .floor_ref = undefined,
        .height_index = undefined,
        .floor_by_height_index = undefined,
    } }};

    const result = canPass(alloc, mover_col, &newloc_col, &[_]col.ColliderData{});
    defer result.bumped.deinit();

    try std.testing.expect(!result.allowed);
    try std.testing.expectEqual(result.new_collision_bitmask, mover_col.collision_bitmask >> 1);
    try std.testing.expectEqual(result.bumped.items.len, 0);
}
