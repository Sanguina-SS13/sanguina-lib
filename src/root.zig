//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const core = @import("exports/core.zig");
export const init = core.init;
export const deinit = core.deinit;

const collision = @import("exports/collision.zig");
export const enter_stacked = collision.enter_stacked;
export const entered_stacked = collision.entered_stacked;
export const get_floor_at = collision.get_floor_at;
export const get_floor_top = collision.get_floor_top;
export const get_floor_below = collision.get_floor_below;
