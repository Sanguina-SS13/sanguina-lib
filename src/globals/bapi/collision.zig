// max value representable through 3 float mantissas
const std = @import("std");
const bapi = @import("byondapi");
const globals = @import("globals");

const col = @import("../collision.zig");
const render = @import("render.zig");
const types = @import("types.zig");

pub const MAX_HEIGHT = 72;

fn import_bitfield(atom: bapi.ByondValue, comptime is_turf: bool) u72 {
    const sref = types.strRefs;
    const id_a = if (is_turf) sref.turf_bitmask_a else sref.movable_bitmask_a;
    const id_b = if (is_turf) sref.turf_bitmask_b else sref.movable_bitmask_b;
    const id_c = if (is_turf) sref.turf_bitmask_c else sref.movable_bitmask_c;

    const a: u72 = @intFromFloat(atom.readVarByID(id_a).asNum());
    const b: u72 = @intFromFloat(atom.readVarByID(id_b).asNum());
    const c: u72 = @intFromFloat(atom.readVarByID(id_c).asNum());

    return (a << 0) | (b << 24) | (c << 48);
}

fn export_bitfield(atom: bapi.ByondValue, bitfield: u72, comptime is_turf: bool) void {
    const sref = types.strRefs;
    const id_a = if (is_turf) sref.turf_bitmask_a else sref.movable_bitmask_a;
    const id_b = if (is_turf) sref.turf_bitmask_b else sref.movable_bitmask_b;
    const id_c = if (is_turf) sref.turf_bitmask_c else sref.movable_bitmask_c;

    const f1: f32 = @floatFromInt((bitfield << 0) & ~@as(u24, 0));
    const f2: f32 = @floatFromInt((bitfield << 24) & ~@as(u24, 0));
    const f3: f32 = @floatFromInt((bitfield << 48) & ~@as(u24, 0));

    atom.writeVarByID(id_a, bapi.getNumber(f1));
    atom.writeVarByID(id_b, bapi.getNumber(f2));
    atom.writeVarByID(id_c, bapi.getNumber(f3));
}

fn decode_zebra(zebra: u72, allocator: std.mem.Allocator) std.ArrayList(u72) {
    var ret = std.ArrayList(u72).init(allocator);

    // given 11000100..
    var markers = (zebra >> 1) ^ zebra; // 10100110 (start of each bit run)
    var total_shift: u7 = 0;
    while (markers != 0) {
        const bit_count = @ctz(markers) + 1; // 2
        const mask = (@as(u72, 1) << bit_count) - 1; // 001 => 100 => 011
        ret.append(mask << @intCast(total_shift)) catch unreachable; // shift to align
        total_shift += bit_count; // adjust the shift
        markers >>= bit_count; // and get the next group in line
    }

    return ret;
}

pub fn update_movable_collision(collision: col.CollisionData) void {
    const movable = collision.ref;
    const height_movable = @clz(collision.collision_bitmask);
    const sref = types.strRefs;

    export_bitfield(movable, collision.collision_bitmask, false);

    const plane: f32 = render.PLANE_FLOOR - @as(f32, @floatFromInt(height_movable)) + 1;
    movable.writeVarByID(sref.plane, bapi.getNumber(plane));
    movable.writeVarByID(sref.invisibility, bapi.getNumber(@floatFromInt(height_movable)));
    if (movable.inner.type == .Mob) {
        // TODO
        movable.writeVarByID(sref.see_invisible, bapi.getNumber(MAX_HEIGHT)); // for now just make it so you can see all floors at once
    }
}

/// Fetches collision data through the floor_by_height_index table. DOES NOT ENSURE MUTABILITY OF THE CONTAINED REFS.
pub fn fetch_floor_colliders(turf: bapi.ByondValue, allocator: std.mem.Allocator) std.ArrayList(?col.CollisionData) {
    const sref = types.strRefs;
    const floor_data = turf.readVarByID(sref.floor_by_height_index);

    return switch (floor_data.inner.type) {
        .List => {
            // list of floor_data paths/instances/nulls
            @branchHint(.unlikely);
            const decoded = decode_zebra(import_bitfield(turf, true), allocator);
            defer decoded.deinit();

            const floor_lookup = floor_data.asList(allocator);
            defer allocator.free(floor_lookup);

            var ret = std.ArrayList(?col.CollisionData).initCapacity(allocator, floor_lookup.len) catch unreachable;

            // last element of decoded can be null (open space), and in that case floor_lookup wont store that trailing null
            // so we must iterate through floor_lookup instead of decoded
            for (floor_lookup, 0..) |floor, i| {
                if (floor.inner.type != .Null) {
                    ret.appendAssumeCapacity(col.CollisionData{
                        .collision_bitmask = decoded.items[i],
                        .ref = floor,
                    });
                } else {
                    ret.appendAssumeCapacity(null);
                }
            }

            return ret;
        },
        .Null => {
            // NOTHING, THERE IS NO COLLISION HERE
            @branchHint(.cold);
            return std.ArrayList(?col.CollisionData).init(allocator);
        },
        else => {
            // floor data path/instance
            @branchHint(.likely);

            var ret = std.ArrayList(?col.CollisionData).initCapacity(allocator, 1) catch unreachable;
            ret.appendAssumeCapacity(.{
                .collision_bitmask = import_bitfield(turf, true),
                .ref = floor_data,
            });

            return ret;
        },
    };
}

pub fn fetch_turf_collision(turf: bapi.ByondValue, check_movables: bool, allocator: std.mem.Allocator) std.ArrayList(col.CollisionData) {
    const sref = types.strRefs;
    //    const coords_index = turf.getXYZ().index();
    //    if (!dirty_coords[coords_index])
    //        return collision_map[coords_index];

    var collision_arr = std.ArrayList(col.CollisionData).initCapacity(allocator, 16) catch unreachable;
    // first movables
    if (check_movables) {
        const movable_data = turf.readVarByID(sref.contents).asList(allocator); // contents list is never null
        defer allocator.free(movable_data);

        collision_arr.ensureUnusedCapacity(movable_data.len) catch unreachable;
        // iter in reverse so movable collision is fifo
        var iter = std.mem.reverseIterator(movable_data);
        while (iter.next()) |val| {
            const collision = fetch_movable_collision(val);
            collision_arr.appendAssumeCapacity(collision);
        }
    }

    // then floors. no inverse iter needed here as these don't overlap also cmon why are you relying on wall Bumped()s.
    const floor_refs = fetch_floor_colliders(turf, allocator);
    defer floor_refs.deinit();

    collision_arr.ensureUnusedCapacity(floor_refs.items.len) catch unreachable;
    for (floor_refs.items) |maybe_value| {
        if (maybe_value) |val| {
            collision_arr.appendAssumeCapacity(val);
        }
    }

    // cache that shit
    // collision_map[coords_index].resize(collision_arr.items.len);
    // collision_map[coords_index].replaceRangeAssumeCapacity(0, collision_arr.items.len, collision_arr.items);
    // dirty_coords[coords_index] = false;

    return collision_arr;
}

pub fn fetch_movable_collision(movable: bapi.ByondValue) col.CollisionData {
    return col.CollisionData{
        .collision_bitmask = import_bitfield(movable, false),
        .flags = types.float2flags(col.CollisionFlags, movable.readVarByID(types.strRefs.collision_flags).asNum()),
        .ref = movable,
    };
}
