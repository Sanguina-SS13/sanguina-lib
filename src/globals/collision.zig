const std = @import("std");
const bapi = @import("byondapi");

const core = @import("core.zig");
const types = @import("bapi/types.zig");

pub const ColliderFlags = packed struct(u24) {
    /// noclip
    NOCLIP: bool = false,
    /// if set, ignore step_size checks and hardset height to the highest floored value
    IGNORE_HEIGHT_CHECKS: bool = false,
    /// the movable will not be considered for other movables' collision checks
    PASS_THROUGH: bool = false,
    /// if blocking path, dont call bump on it but still block passage. by default applied to turfs.
    BLOCK_NO_BUMP: bool = false,
    /// dont increase height. equivalent to step_size = 0
    PROHIBIT_HEIGHT_INCREASE: bool = false,

    /// padding so we don't have to downcast all the time
    _: u19 = undefined,
};

pub const FloorCollider = struct {
    collision_bitmask: u72,
    flags: ColliderFlags = .{},
    // TODO nuke all of these and replace with a bapi pointer once lummox gets off of his arse
    turf_ref: bapi.ByondValue,
    floor_ref: bapi.ByondValue,
    height_index: u7,
    floor_by_height_index: bapi.ByondValue,

    pub fn ref(self: FloorCollider, mutable: bool) bapi.ByondValue {
        const sref = types.strRefs;

        const floor_ref = self.floor_ref;
        if (floor_ref.inner.type == .Datum or floor_ref.inner.type == .Null)
            return floor_ref;

        if (!mutable)
            return types.globHolder.readVarByID(sref.glob_floor_type_lookup).at(floor_ref);

        const fbhi = self.floor_by_height_index;
        const new_ref = bapi.new(floor_ref, null);
        if (fbhi.inner.type != .List) {
            self.turf_ref.writeVarByID(sref.floor_by_height_index, new_ref);
        } else {
            fbhi.writeAt(bapi.getNumber(@floatFromInt(self.height_index)), new_ref);
        }
        return new_ref;
    }

    pub fn eql(self: FloorCollider, other: FloorCollider) bool {
        return self.height_index == other.height_index and self.floor_by_height_index.eqlRef(other.floor_by_height_index);
    }
};
pub const MovableCollider = struct {
    collision_bitmask: u72,
    flags: ColliderFlags = .{},
    ref: bapi.ByondValue,
    step_size: u7 = 0,

    pub fn eql(self: MovableCollider, other: MovableCollider) bool {
        return self.ref.eqlRef(other.ref);
    }
};

const ColliderTag = enum { Floor, Movable };
pub const ColliderData = union(ColliderTag) {
    Floor: FloorCollider,
    Movable: MovableCollider,

    pub fn eql(self: ColliderData, other: ColliderData) bool {
        if (@as(ColliderTag, self) != @as(ColliderTag, other))
            return false;

        return switch (self) {
            .Floor => |v| v.eql(other.Floor),
            .Movable => |v| v.eql(other.Movable),
        };
    }

    pub fn ref(self: ColliderData, mutable: bool) bapi.ByondValue {
        return switch (self) {
            .Floor => |v| v.ref(mutable),
            .Movable => |v| v.ref,
        };
    }

    pub fn flags(self: ColliderData) ColliderFlags {
        return switch (self) {
            .Floor => |v| v.flags,
            .Movable => |v| v.flags,
        };
    }

    pub fn bitmask(self: ColliderData) u72 {
        return switch (self) {
            .Floor => |v| v.collision_bitmask,
            .Movable => |v| v.collision_bitmask,
        };
    }
};
