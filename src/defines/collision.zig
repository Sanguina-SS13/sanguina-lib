pub const COLLISION_FLAG = packed struct {
    /// noclip
    NOCLIP: u1,
    /// the movable will not be considered for other movables' collision checks
    PASS_THROUGH: u1,
    /// dont increase height. equivalent to step_size = 0
    PROHIBIT_HEIGHT_INCREASE: u1,
};
