pub const PLANE_FLOOR = -5;

pub fn getFloorPlane(height: u10) f32 {
    return @floatFromInt(PLANE_FLOOR - height + 1);
}
