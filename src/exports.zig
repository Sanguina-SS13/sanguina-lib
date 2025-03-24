const std = @import("std");
const bapi = @import("byondapi");
//const map_gen = @import("map_gen/map_gen.zig");

//export fn generate_map(seed: u64) callconv(.C) void {
//    const generated_map = map_gen.generate_map(seed);
//    _ = generated_map;

//  var map_reference = allocator.alloc(bapi.CByondValue, Z_SIZE_X*Z_SIZE_Y*9) catch unreachable;
//  _ = bapi.Byond_Block(.{1, 1, 1, undefined}, .{Z_SIZE_X, Z_SIZE_Y, 9, undefined}, map_reference, Z_SIZE_X*Z_SIZE_Y*9);
//
//  for (0..SIZE_Z) |zy| {
//        for (0..3) |zx| {
//            // 1 2 3
//            // 4 5 6
//            // 7 8 9
//            const target_turf = map_reference[zx + zy * @sqrt(SIZE_Z)];
//            const created_turf =
//
//            _ = bapi.Byond_New(map_reference[zx + zy * @sqrt(SIZE_Z)], );
//            const z_level = x + (y * 3);
//            const corner_a: bapi.CByondXYZ = .{ 255, 255, z_level, undefined };
//            const corner_b: bapi.CByondXYZ = .{ 255, 255, z_level, undefined };
//        }
//  }
//}
