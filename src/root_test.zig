const std = @import("std");

test "fuck" {
    _ = std.testing.refAllDecls(@import("collision/can_pass.zig"));
    _ = std.testing.refAllDecls(@import("collision/find_free_space.zig"));
}
