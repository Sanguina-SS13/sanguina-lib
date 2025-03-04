const std = @import("std");
const def = @import("../defines.zig");
const SIZE_TOTAL = def.SIZE_X * def.SIZE_Y * def.SIZE_Z;

//random shit
//pub fn interpolate_smoothstep(x1: f32, x2: f32, weight: f32) f32 {
//    return (x2 - x1) * ((weight * (weight * 6.0 - 15.0) + 10.0) * weight * weight * weight) + x1;
//}
//pub fn interpolate_linear(x1: f32, x2: f32, weight: f32) f32 {
//    return (x2 - x1) * weight + x1;
//}
//
//const permutation = [_]u8{
//    151, 160, 137, 91,  90,  15,  131, 13,  201, 95,  96,  53,  194, 233, 7,   225,
//    140, 36,  103, 30,  69,  142, 8,   99,  37,  240, 21,  10,  23,  190, 6,   148,
//    247, 120, 234, 75,  0,   26,  197, 62,  94,  252, 219, 203, 117, 35,  11,  32,
//    57,  177, 33,  88,  237, 149, 56,  87,  174, 20,  125, 136, 171, 168, 68,  175,
//    74,  165, 71,  134, 139, 48,  27,  166, 77,  146, 158, 231, 83,  111, 229, 122,
//    60,  211, 133, 230, 220, 105, 92,  41,  55,  46,  245, 40,  244, 102, 143, 54,
//    65,  25,  63,  161, 1,   216, 80,  73,  209, 76,  132, 187, 208, 89,  18,  169,
//    200, 196, 135, 130, 116, 188, 159, 86,  164, 100, 109, 198, 173, 186, 3,   64,
//    52,  217, 226, 250, 124, 123, 5,   202, 38,  147, 118, 126, 255, 82,  85,  212,
//    207, 206, 59,  227, 47,  16,  58,  17,  182, 189, 28,  42,  223, 183, 170, 213,
//    119, 248, 152, 2,   44,  154, 163, 70,  221, 153, 101, 155, 167, 43,  172, 9,
//    129, 22,  39,  253, 19,  98,  108, 110, 79,  113, 224, 232, 178, 185, 112, 104,
//    218, 246, 97,  228, 251, 34,  242, 193, 238, 210, 144, 12,  191, 179, 162, 241,
//    81,  51,  145, 235, 249, 14,  239, 107, 49,  192, 214, 31,  181, 199, 106, 157,
//    184, 84,  204, 176, 115, 121, 50,  45,  127, 4,   150, 254, 138, 236, 205, 93,
//    222, 114, 67,  29,  24,  72,  243, 141, 128, 195, 78,  66,  215, 61,  156, 180,
//};
//
//fn permute(index: i32) u8 {
//    return permutation[@intCast(index & 255)];
//}
//
//const Vector2 = struct { x: f32, y: f32 };
//fn gradient_rand(ix: i32, iy: i32) Vector2 {
//    const idx = permute(ix + permute(iy));
//    const angle = @as(f32, @floatFromInt(idx)) * (2.0 * std.math.pi / 256.0);
//    return Vector2{ .x = std.math.cos(angle), .y = std.math.sin(angle) };
//}
//
//fn gradient_dot_grid(ix: i32, iy: i32, x: f32, y: f32) f32 {
//    const gradient = gradient_rand(ix, iy);
//    const dx = x - @as(f32, @floatFromInt(ix));
//    const dy = y - @as(f32, @floatFromInt(iy));
//    return dx * gradient.x + dy * gradient.y;
//}
//
//pub fn perlin_noise(x: f32, y: f32) f32 {
//    const x0 = @as(i32, @intFromFloat(std.math.floor(x)));
//    const x1 = x0 + 1;
//    const y0 = @as(i32, @intFromFloat(std.math.floor(y)));
//    const y1 = y0 + 1;
//
//    const sx = x - @as(f32, @floatFromInt(x0));
//    const sy = y - @as(f32, @floatFromInt(y0));
//
//    const n0 = gradient_dot_grid(x0, y0, x, y);
//    const n1 = gradient_dot_grid(x1, y0, x, y);
//    const ix0 = interpolate_linear(n0, n1, sx);
//
//    const n2 = gradient_dot_grid(x0, y1, x, y);
//    const n3 = gradient_dot_grid(x1, y1, x, y);
//    const ix1 = interpolate_linear(n2, n3, sx);
//
//    const value = interpolate_linear(ix0, ix1, sy);
//    return value;
//}
//
//pub fn perlin_grid(offset_x: f32, offset_y: f32, magnitude: f32, width: u8, height: u8) [width * height]f32 {
//    var ret: [width * height]f32 = undefined;
//    for (0..height) |y| {
//        for (0..width) |x| {
//            const ox = offset_x + @as(f32, @floatFromInt(x)) * magnitude;
//            const oy = offset_y + @as(f32, @floatFromInt(y)) * magnitude;
//            const value = perlin_noise(ox, oy);
//
//            std.debug.print("{c}", .{if (value > 0.0) "█" else "▒"});
//            ret[x + y * width] = value;
//        }
//        std.debug.print("\n", .{});
//    }
//    return ret;
//}

pub fn cell_auto(map_slice: *[SIZE_TOTAL]bool, buffer: *[SIZE_TOTAL]bool, width: comptime_int, alive_states: [9]bool, dead_states: [9]bool) void {
    const length = map_slice.len;

    for (0..length) |index| {
        var alive_count: u8 = 0;

        if (index > width + 1) {
            alive_count += @intFromBool(buffer[index - width - 1]);
        }
        if (index > width) {
            alive_count += @intFromBool(buffer[index - width]);
        }
        if (index > width - 1) {
            alive_count += @intFromBool(buffer[index - width + 1]);
        }
        if (index >= 1) {
            alive_count += @intFromBool(buffer[index - 1]);
        }
        if (index + 1 < length) {
            alive_count += @intFromBool(buffer[index + 1]);
        }
        if (index + width - 1 < length) {
            alive_count += @intFromBool(buffer[index + width - 1]);
        }
        if (index + width < length) {
            alive_count += @intFromBool(buffer[index + width]);
        }
        if (index + width + 1 < length) {
            alive_count += @intFromBool(buffer[index + width + 1]);
        }

        if (alive_states[alive_count]) {
            map_slice[index] = true;
        } else if (dead_states[alive_count]) {
            map_slice[index] = false;
        }
    }
}

pub fn drunk_walk(
    map_slice: *[SIZE_TOTAL]bool,
    width: comptime_int,
    steps: comptime_int,
    start_index: u16,
    weights: struct { north: u8, south: u8, east: u8, west: u8 },
    randomizer: std.Random,
) void {
    const south_threshold = weights.north;
    const east_threshold = south_threshold + weights.south;
    const west_threshold = east_threshold + weights.east;

    std.debug.assert(west_threshold + weights.west == std.math.maxInt(u8));

    var index = start_index;
    map_slice[start_index] = true;
    for (0..steps) |_| {
        const rand = randomizer.int(u8);
        //north
        if (rand < south_threshold) {
            if (index < width)
                continue;
            index -= width;
        }
        //south
        else if (rand < east_threshold) {
            if (index + width >= map_slice.len)
                continue;
            index += width;
        }
        //east
        else if (rand < west_threshold) {
            if ((index % width) + 1 >= width)
                continue;
            index += 1;
        }
        //west
        else {
            if ((index % width) <= 1)
                continue;
            index -= 1;
        }

        map_slice[index] = true;
    }
}
