const std = @import("std");
const bapi = @import("byondapi");
const globals = @import("globals");

const col = globals.collision;
const bit = globals.bitmath;

const CanPassMovableResult = struct {
    passable: bool,
    bumped: bool,
};
fn can_pass_movable(mover_col: col.CollisionDataExpanded, bumped: col.CollisionData) CanPassMovableResult {
    const ret = CanPassMovableResult;

    if (mover_col.ref.eqlRef(bumped.ref)) {
        @branchHint(.unlikely);
        return ret{ .bumped = false, .passable = true }; // dont collide with yourself kthx
    }
    if (bumped.collision_bitmask & bumped.collision_bitmask == 0)
        // no collision
        return ret{ .bumped = false, .passable = true };

    // we collide, but can we pass
    if (bumped.flags.PASS_THROUGH) {
        @branchHint(.unlikely);
        return ret{ .bumped = true, .passable = true };
    }
    // do we bump?
    if (bumped.flags.BLOCK_NO_BUMP) {
        @branchHint(.unlikely);
        return ret{ .bumped = false, .passable = false };
    }
    // regular ass blocker
    return ret{ .bumped = true, .passable = false };
}

const CanPassResult = struct {
    allowed: bool,
    new_collision_bitmask: u72,
    bumped: std.ArrayList(col.CollisionData),
};
pub fn can_pass(alloc: std.mem.Allocator, mover_col: col.CollisionDataExpanded, newloc_cols: []const col.CollisionData, oldloc_cols: []const col.CollisionData) CanPassResult {
    var ret = CanPassResult{
        .allowed = false,
        .new_collision_bitmask = mover_col.collision_bitmask,
        .bumped = std.ArrayList(col.CollisionData).init(alloc),
    };
    if (mover_col.flags.NOCLIP) {
        @branchHint(.unlikely);
        ret.allowed = true;
        return ret;
    }

    var passthroughs = std.ArrayList(col.CollisionData).initCapacity(alloc, 4) catch unreachable;
    defer passthroughs.deinit();

    const mover_head = bit.head_bit(mover_col.collision_bitmask);

    var bumped: ?col.CollisionData = null;
    outer: for (0..@min(mover_col.step_size, @ctz(mover_head)) + 1) |i| {
        if (i != 0) {
            // check if we're not bumping into a ceiling
            inner: for (oldloc_cols) |collider| {
                const cp = can_pass_movable(mover_col, collider);
                if (!cp.passable) {
                    continue :outer;
                }

                if (cp.bumped) {
                    for (passthroughs.items) |passer| {
                        if (passer.ref.eqlRef(collider.ref))
                            continue :inner;
                    }
                    passthroughs.append(collider) catch unreachable;
                    continue;
                }
            }
        }

        var blocked_movement = false;
        inner: for (newloc_cols) |collider| {
            const cp = can_pass_movable(mover_col, collider);
            if (cp.passable) {
                if (cp.bumped) {
                    for (passthroughs.items) |passer| {
                        if (passer.ref.eqlRef(collider.ref))
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

test "can_pass" {
    const CollisionData = col.CollisionData;
    const CollisionDataExpanded = col.CollisionDataExpanded;

    const alloc = std.testing.allocator;

    var mover_col = CollisionDataExpanded{
        .collision_bitmask = 0,
        .flags = .{},
        .ref = bapi.getNumber(1).inner,
        .step_size = 1,
    };
    var newloc_col = [2]CollisionData{
        CollisionData{ .collision_bitmask = 0, .flags = .{}, .ref = bapi.getNumber(2).inner },
        CollisionData{ .collision_bitmask = 0, .flags = .{}, .ref = bapi.getNumber(3).inner },
    };
    var oldloc_cols = [2]CollisionData{
        CollisionData{ .collision_bitmask = 0, .flags = .{}, .ref = bapi.getNumber(4).inner },
    };

    var result: CanPassResult = undefined;

    // Test case 1: No collision
    mover_col.collision_bitmask =
        0b00000000_11100000_00000000;
    newloc_col[0].collision_bitmask =
        0b11111111_00000000_00000000;
    oldloc_cols[0].collision_bitmask =
        0b00000000_00000000_00000000;

    result = can_pass(alloc, mover_col, newloc_col, oldloc_cols);
    defer result.bumped.deinit();
    std.debug.assert(result.allowed == true);
    std.debug.assert(result.new_collision_bitmask == mover_col.collision_bitmask);
    std.debug.assert(result.bumped.items.len == 0);

    // Test case 2: Step up + passthrough
    mover_col.collision_bitmask =
        0b00000000_11100000_00000000;
    newloc_col[0].collision_bitmask =
        0b11111111_10000000_00000000;
    newloc_col[1].collision_bitmask =
        0b00000000_00011000_00000000;
    newloc_col[1].flags.PASS_THROUGH = true;
    oldloc_cols[0].collision_bitmask =
        0b00000000_00000000_00000000;

    result = can_pass(alloc, mover_col, newloc_col, oldloc_cols);
    defer result.bumped.deinit();
    std.debug.assert(result.allowed == true);
    std.debug.assert(result.new_collision_bitmask == mover_col.collision_bitmask >> 1);
    std.debug.assert(result.bumped.items.len == 1 and std.mem.eql(result.bumped.items[0], newloc_col[1]));

    // Test case 3: Blocked by newloc
    mover_col.collision_bitmask =
        0b00000000_11100000_00000000;
    newloc_col[0].collision_bitmask =
        0b11111111_11100000_00000000;
    oldloc_cols[0].collision_bitmask =
        0b00000000_00000000_00000000;
    result = can_pass(alloc, mover_col, newloc_col, oldloc_cols);
    defer result.bumped.deinit();
    std.debug.assert(result.allowed == false);
    std.debug.assert(result.new_collision_bitmask == mover_col.collision_bitmask);
    std.debug.assert(result.bumped.items.len == 0);

    // Test case 4: Wacky newloc
    mover_col.collision_bitmask =
        0b00000000_11100000_00000000;
    newloc_col[0].collision_bitmask =
        0b10101010_10101010_10101010;
    oldloc_cols[0].collision_bitmask =
        0b00000000_00000000_00000000;

    newloc_col[1].flags.BLOCK_NO_BUMP = true;

    result = can_pass(alloc, mover_col, newloc_col, oldloc_cols);
    defer result.bumped.deinit();
    std.debug.assert(result.allowed == false);
    std.debug.assert(result.new_collision_bitmask == mover_col.collision_bitmask);
    std.debug.assert(result.bumped.items.len == 0);

    // Test case 5: Ceiling bump
    mover_col.collision_bitmask =
        0b00000000_11100000_00000000;
    newloc_col[0].collision_bitmask =
        0b11111111_10000000_00000000;
    oldloc_cols[0].collision_bitmask =
        0b00000000_00011111_00000000;
    result = can_pass(alloc, mover_col, newloc_col, oldloc_cols);
    defer result.bumped.deinit();
    std.debug.assert(result.allowed == false);
    std.debug.assert(result.new_collision_bitmask == mover_col.collision_bitmask);
    std.debug.assert(result.bumped.items.len == 1 and std.mem.eql(result.bumped.items[0], newloc_col[0]));
}
