const bapi = @import("byondapi");

pub const CollisionFlags = packed struct(u24) {
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

pub const CollisionData = struct {
    collision_bitmask: u72,
    flags: CollisionFlags = .{},
    ref: bapi.ByondValue,
};

/// i hate the world we live in
pub const CollisionDataExpanded = struct {
    collision_bitmask: u72,
    flags: CollisionFlags = .{},
    ref: bapi.ByondValue,
    step_size: u7,
};
