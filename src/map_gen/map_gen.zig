const std = @import("std");
const alg = @import("alg.zig");
const def = @import("../defines.zig");
const types = @import("_compgen_out.zig");

const AREA = def.AREA;
const TURF = def.TURF;

const SIZE_X = def.SIZE_X;
const SIZE_Y = def.SIZE_Y;
const SIZE_Z = def.SIZE_Z;

fn apply_structures(map: []def.tile_data) void {
    _ = map;
}

pub fn generate_map(seed: u64) []def.tile_data {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();

    var xoshiro = std.Random.Xoshiro256.init(seed);
    const randomizer = xoshiro.random();

    const allocator = gpa.allocator();

    // -------- cell auto -----------
    // generate noise
    var cellular_grid: [SIZE_X * SIZE_Y * SIZE_Z]bool = undefined;
    for (0..SIZE_X * SIZE_Y * SIZE_Z) |i| {
        cellular_grid[i] = randomizer.int(u8) > @trunc(255 * 0.5);
    }

    var buffer: [SIZE_X * SIZE_Y * SIZE_Z]bool = undefined;
    for (0..10) |_| {
        const ALIVE_STATES: [9]bool = .{ false, false, false, false, false, true, true, true, true };
        const DEAD_STATES: [9]bool = .{ true, true, true, true, false, false, false, false, false };

        alg.cell_auto(&buffer, &cellular_grid, comptime SIZE_X * 3, ALIVE_STATES, DEAD_STATES);
        alg.cell_auto(&cellular_grid, &buffer, comptime SIZE_X * 3, ALIVE_STATES, DEAD_STATES);
    }

    var formatted_map = allocator.alloc(def.tile_data{}, SIZE_X * SIZE_Y * SIZE_Z) catch unreachable;
    defer allocator.destroy(formatted_map);

    _ = &formatted_map;

    // divide by biome
    //    const offset_x = randomizer.float(f32) * 32768;
    //    const offset_y = randomizer.float(f32) * 32768;
    //    var temperature: [SIZE_X * SIZE_Y]f32 = undefined;
    //    var height: [SIZE_X * SIZE_Y]f32 = undefined;
    //
    //    for (0..SIZE_Y) |y| {
    //        for (0..SIZE_X) |x| {
    //            const ox = offset_x + @as(f32, @floatFromInt(x)) * 1;
    //            const oy = offset_y + @as(f32, @floatFromInt(y)) * 1;
    //            const value = alg.perlin_noise(ox, oy);
    //
    //            std.debug.print("{c}", .{if (value > 0.0) "█" else "▒"});
    //
    //            temperature[x + y * SIZE_X] = alg.perlin_noise(
    //                offset_x + @as(f32, @floatFromInt(x)),
    //                offset_y + @as(f32, @floatFromInt(y)),
    //            );
    //            height[x + y * SIZE_X] = alg.perlin_noise(
    //                offset_x + @as(f32, @floatFromInt(x)),
    //                offset_y + @as(f32, @floatFromInt(y)),
    //            );
    //        }
    //    }

    //var biome_grid: [TOTAL_SIZE_X * TOTAL_SIZE_Y]AREA = @splat(AREA.WASTES);
}
