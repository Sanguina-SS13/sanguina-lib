const std = @import("std");
const zig = @import("../defines/zig.zig");

const bapi = @import("../byondapi/_byondapi.zig");
const types = @import("../byondapi/types.zig");
const collision = @import("../byondapi/collision.zig");

const COLLISION = @import("../defines/collision.zig").COLLISION_FLAG;
const sref = types.strRefs;

fn decode_zebra(zebra: u72, allocator: std.mem.Allocator) std.ArrayList(u72) {
    var ret = std.ArrayList(u72).init(allocator);

    // given 11000100..
    var markers = (zebra >> 1) ^ zebra; // 10100110 (start of each seq)
    var total_shift = 0;
    while (markers != 0) {
        const bit_count = @ctz(markers) + 1; // 2
        const mask = (1 << bit_count) - 1; // 001 => 100 => 011
        ret.append(mask << @intCast(total_shift)) catch unreachable; // shift to align
        total_shift += bit_count; // adjust the shift
        markers >>= bit_count; // and get the next group in line
    }

    return ret;
}
//
// shamelessly ripped from chatgpt
fn dist_above_floor(floor: u72, mover: u72) u72 {
    std.debug.assert(mover != 0);

    // Determine b's leftmost set bit (most significant bit set)
    // Note: std.builtin.bitSize(u72) gives the total bit-width.
    const bLeft = (@typeInfo(u72).int.bits - 1) - @clz(mover);

    // Isolate from 'a' only those bits that are strictly to the left of b's leftmost set bit.
    // The mask (~0 << (bLeft + 1)) has all bits set from position (bLeft+1) upward.
    const candidate = floor & (~@as(u72, 0) << @intCast(bLeft + 1));

    // The rightmost set bit in 'candidate' (i.e. the boundary of the relevant region in a)
    const aBoundary = @ctz(candidate);

    // The gap is the number of zeros between that bit and b's leftmost set bit.
    return aBoundary - bLeft - 1;
}

export fn enter_stacked(_mover: bapi.ByondValueRaw, _new_loc: bapi.ByondValueRaw, _old_loc: bapi.ByondValueRaw) callconv(.C) bapi.ByondValueRaw {
    const mover: bapi.ByondValue = .{ .inner = _mover };
    const new_loc: bapi.ByondValue = .{ .inner = _new_loc };
    const old_loc: bapi.ByondValue = .{ .inner = _old_loc };

    var ret: bapi.ByondValue = undefined;

    const crosser_collision_flags = mover.readVarByID(mover, sref.collision_flags).asNum();
    if (@trunc(crosser_collision_flags) & COLLISION.NOCLIP) {
        @branchHint(.unlikely);
        return ret.writeNum(1);
    }

    var alloc = zig.local_alloc;

    var mover_bounds = collision.import_collision_bitfield(mover);
    const turf_zebra = collision.import_turfmask_bitfield(new_loc);

    var atom_bounds = std.ArrayList(bapi.ByondValue).initCapacity(alloc, 16) catch unreachable;
    defer alloc.free(atom_bounds);
    var atom_data = std.ArrayList(bapi.ByondValue).initCapacity(alloc, 16) catch unreachable;
    defer alloc.free(atom_data);

    const _turf_data = new_loc.readVarByID(sref.floor_by_height_index);
    var total_collision_bitmask: u72 = 0;

    switch (_turf_data.inner.type) {
        .Null => {
            @branchHint(.cold);
            var ret: bapi.ByondValue = undefined;
            return ret.writeNum(0);
        },
        .List => {
            @branchHint(.unlikely);
            const turf_bounds = decode_zebra(turf_zebra, alloc);
            defer alloc.free(turf_bounds);

            const turf_data = _turf_data.asList(alloc); //asserted isList already
            defer alloc.free(turf_data);

            for (turf_data, 0..) |value, i| {
                if (value.inner.type == .Null)
                    continue;

                atom_data.append(value);
                atom_bounds.append(turf_bounds[i]);
                total_collision_bitmask |= turf_bounds[i];
            }
        },
        _ => {
            @branchHint(.likely);
            atom_data.append(_turf_data);
            atom_bounds.append(turf_zebra);
            total_collision_bitmask |= turf_zebra;
        },
    }

    const contents = _turf_data.readVarByID(sref.contents).asList(alloc);
    defer alloc.free(contents);

    for (contents) |atom_ref| {
        const collision_flags = @trunc(atom_ref.readVarByID(sref.collision_flags).asNum());
        if (collision_flags & COLLISION.PASS_THROUGH) {
            continue;
        }

        const bounds = collision.import_collision_bitfield(atom_ref);
        atom_data.append(atom_ref);
        atom_bounds.append(bounds);
        total_collision_bitmask |= bounds;
    }

    // now the actual meat
    var moved_up = false;
    if (total_collision_bitmask & mover_bounds != 0) brk: {
        moved_up = true;
        if (@ctz(mover_bounds) == 0)
            break :brk;

        const mover_step_size: u24 = @trunc(mover.readVarByID(sref.z_step_size).asNum());
        var bitshifted = mover_bounds;
        for (0..mover_step_size) |_| {
            bitshifted = @shrExact(bitshifted, 1);
            if (mover_bounds & total_collision_bitmask == 0) {
                mover_bounds = bitshifted;
                break :brk;
            }

            if (@ctz(mover_bounds) == 0)
                break :brk;
        }
    }
    if (total_collision_bitmask & mover_bounds == 0) {
        var height_above_floor: u24 = undefined;
        const floor_or_null: ?bapi.ByondValue = {
            if (@clz(total_collision_bitmask) >= @clz(mover_bounds)) {
                @branchHint(.unlikely);
                return null;
            }
            const checked_bit = if (moved_up) {
                height_above_floor = 0;
                return ((mover_bounds << 1) | mover_bounds) ^ mover_bounds;
            } else {
                height_above_floor = dist_above_floor(total_collision_bitmask, mover_bounds);
                return (((mover_bounds << 1) | mover_bounds) ^ mover_bounds) << height_above_floor - 2;
            };

            for (atom_bounds, 0..) |bounds, i| {
                if (bounds & checked_bit == 0)
                    continue;

                return atom_data[i];
            }
            return null;
        };

        if (floor_or_null == null) {
            // YOU FALLIN INTO THE ABYSS M80
            @branchHint(.unlikely);
            // TODO
            return ret.writeNum(0);
        }

        if (moved_up) {
            collision.export_collision_bitfield(mover, mover_bounds);
            //var val: bapi.ByondValue = undefined;
            //mover.writeVarByID(sref.plane, val.writeNum(@clz(mover_bounds)));
        }

        const VTag = bapi.ValueTag;
        const floor = floor_or_null.?;

        switch (floor.inner.type) {
            // movable
            VTag.Obj, VTag.Mob => floor.callByID(sref.proc_walked_on, .{mover}),
            // /datum/floor_type instance
            VTag.Datum => _ = floor.callByID(sref.proc_walked_on, .{mover}),
            // /datum/floor_type typepath
            VTag.DatumTypepath => {
                const floor_type = floor.toString(alloc);
                defer alloc.free(floor_type);
                const proc_name = std.mem.concat(alloc, u8, .{ floor_type, "::SteppedOn()" }) catch unreachable;
                defer alloc.free(proc_name);

                _ = bapi.callGlobal(proc_name, .{mover});
            },
            _ => unreachable,
        }

        return ret.writeNum(1);
    } else {
        const bumped: bapi.ByondValue = {
            for (atom_bounds, 0..) |bounds, i| {
                if (bounds & mover_bounds != 0)
                    return atom_data[i];
            }
            unreachable;
        };
        // let the mover know..
        _ = mover.callByID(sref.proc_blocked, .{bumped});

        // .. as well as the wall itself
        const VTag = bapi.ValueTag;
        switch (bumped.inner.type) {
            // movable
            VTag.Obj, VTag.Mob => bumped.callByID(sref.proc_bump, .{mover}),
            // /datum/floor_type instance
            VTag.Datum => _ = bumped.callByID(sref.proc_bump, .{mover}),
            // /datum/floor_type typepath
            VTag.DatumTypepath => {
                const floor_type = bumped.toString(alloc);
                defer alloc.free(floor_type);
                const proc_name = std.mem.concat(alloc, u8, .{ floor_type, "::Bump()" }) catch unreachable;
                defer alloc.free(proc_name);

                _ = bapi.callGlobal(proc_name, .{mover});
            },
            _ => unreachable,
        }

        return ret.writeNum(0);
    }

    // var total_collision_mask: u72 = 0;
    // var collision_masks_turfs = std.ArrayList(u72).initCapacity(alloc, 8) catch unreachable;
    // var collision_masks_movables = std.ArrayList(u72).initCapacity(alloc, 8) catch unreachable;
    // defer alloc.free(collision_masks_turfs);
    // defer alloc.free(collision_masks_movables);

    // // turfs
    // _ = bapi.Byond_ReadVarByStrId(&target_turf, sref.turf_floor_by_height, &var_ref);
    // const ref_floor_by_height = var_ref; // ..and the type of the floor
    // {
    //     const turf_zebra_bitmask = extract_bitfield_turf(target_turf);
    //     if (bapi.ByondValue_IsList(ref_floor_by_height)) {
    //         @branchHint(.unlikely);
    //         const floor_by_height = bapi.read_list(ref_floor_by_height);

    //         // given 11000100..
    //         var markers = (turf_zebra_bitmask >> 1) ^ turf_zebra_bitmask; // 10100110 (start of each seq)
    //         var total_shift = 0;
    //         var i = 0;
    //         while (markers != 0) {
    //             if (!(i < floor_by_height.len))
    //                 // we're at the last mask, and its null (therefore no array entry)
    //                 break;

    //             const bit_count = @ctz(markers) + 1; // 2
    //             const mask = (1 << bit_count) - 1; // 001 => 100 => 011
    //             if (bapi.ByondValue_IsNull(floor_by_height[i]))
    //                 collision_masks_turfs.append(0) catch unreachable
    //             else {
    //                 const collision_box = mask << @intCast(total_shift); //shift to align
    //                 total_collision_mask |= collision_box;
    //                 collision_masks_turfs.append(collision_box) catch unreachable;
    //             }

    //             total_shift += bit_count; // adjust the shift
    //             markers >>= bit_count; // and get the next group in line
    //             i += 1;
    //         }
    //     } else if (!bapi.ByondValue_IsNull(ref_floor_by_height)) {
    //         @branchHint(.likely);
    //         total_collision_mask |= turf_zebra_bitmask;
    //         collision_masks_turfs.append(turf_zebra_bitmask);
    //     } else {
    //         @branchHint(.cold);
    //     }
    // }
    // const mover_max_height_adjust = 1; // TODO figure a better name also unhardcode it
    // var mover_bitmask = extract_bitfield_movable(mover);
    // if (total_collision_mask & mover_bitmask != 0 and total_collision_mask & (mover_bitmask >> mover_max_height_adjust) != 0) {
    //     // not much point to continue is there
    //     return bapi.set_num(0);
    // }

    // // movables
    // const contents = bapi.read_list(bapi.read_var(target_turf, sref.contents));
    // for (contents) |atom_ref| {
    //     const collision_flags = @trunc(bapi.get_num(bapi.read_var(atom_ref, sref.collision_flags)));
    //     if (collision_flags & (COLLISION.NOCLIP | COLLISION.PASS_THROUGH) != 0) {
    //         //lets not cockblock ppl through admeme fuckery
    //         collision_masks_movables.append(0);
    //         continue;
    //     }

    //     const collision = extract_bitfield_movable(atom_ref);
    //     collision_masks_movables.append(collision);
    //     total_collision_mask |= collision;
    // }

    // // now the actual meat
    // var moved_up = false;
    // if (total_collision_mask & mover_bitmask != 0) {
    //     if ((mover_bitmask >> mover_max_height_adjust) & total_collision_mask == 0) {
    //         // TODO fix for custom step sizes
    //         moved_up = true;
    //         mover_bitmask >>= mover_max_height_adjust;
    //     }
    // }

    // if (total_collision_mask & mover_bitmask == 0) {
    //     const floor: ?bapi.ByondValue = {
    //         if (!moved_up and @clz(total_collision_mask) >= @clz(mover_bitmask)) {
    //             @branchHint(.unlikely);
    //             return null;
    //         }
    //         const checked_bit = if (moved_up)
    //             ((mover_bitmask << 1) | mover_bitmask) ^ mover_bitmask
    //         else
    //             dist_above_floor(total_collision_mask, mover_bitmask);

    //         for (collision_masks_turfs, 0..) |collision, i| {
    //             if (collision & checked_bit == 0)
    //                 continue;

    //             const floor_by_height = bapi.read_list(ref_floor_by_height);
    //             return floor_by_height[i];
    //         }

    //         for (collision_masks_movables, 0..) |collision, i| {
    //             if (collision & checked_bit == 0)
    //                 continue;

    //             return contents[i];
    //         }

    //         return null;
    //     };

    //     if (floor == null) {
    //         // YOU FALLIN INTO THE ABYSS M80
    //         @branchHint(.unlikely);
    //         // TODO
    //         return bapi.set_num(1);
    //     }

    //     if (moved_up) {
    //         //collapse the value back into 3 floats
    //         const f1: f32 = @bitCast(mover_bitmask & @as(u24, ~0));
    //         const f2: f32 = @bitCast((mover_bitmask << 24) & @as(u24, ~0));
    //         const f3: f32 = @bitCast((mover_bitmask << 48) & @as(u24, ~0));

    //         bapi.set_num(bapi.read_var(&mover, sref.movable_bitmask_a), f1);
    //         bapi.set_num(bapi.read_var(&mover, sref.movable_bitmask_b), f2);
    //         bapi.set_num(bapi.read_var(&mover, sref.movable_bitmask_c), f3);
    //     }

    //     const VTag = bapi.ValueTag;
    //     switch (floor.?.type) {
    //         // movable
    //         VTag.Obj, VTag.Mob => _ = bapi.call_proc(floor.?, sref.proc_walked_on, mover, 1),
    //         // /datum/floor_type instance
    //         VTag.Datum => _ = bapi.call_proc(floor.?, sref.proc_walked_on, mover, 1),
    //         // /datum/floor_type typepath
    //         VTag.DatumTypepath => {
    //             const proc_name = std.mem.concat(alloc, u8, .{ bapi.to_string(floor.?), "::WalkedOn()" }) catch unreachable;
    //             defer alloc.free(proc_name);

    //             bapi.call_global_proc(proc_name, mover, 1);
    //         },
    //         _ => unreachable,
    //     }
    //     return bapi.set_num(0);
    // } else {
    //     @compileError("FINISH");
    // }

    // _ = bapi.Byond_ReadVarByStrId(&target_turf, sref.turf_floor_by_height, &var_ref);
    // const ref_floor_by_height = var_ref; // ..and the type of the floor

    // var move_succeeded = true;
    // var bumped: ?bapi.ByondValue = null;
    // var floor: ?bapi.ByondValue = null;

    // _ = overlap_check: {
    //     // first the turfs
    //     if (bapi.ByondValue_IsList(ref_floor_by_height)) not_it: {
    //         @branchHint(.unlikely);

    //         const colliders = decode_zebra(turf_zebra_bitmask, alloc);
    //         defer alloc.free(colliders);

    //         const len_floor_by_height: bapi.u4c = undefined;
    //         _ = bapi.Byond_ReadList(ref_floor_by_height, null, &len_floor_by_height);
    //         const floor_by_height: [len_floor_by_height]bapi.ByondValue = undefined;
    //         _ = bapi.Byond_ReadList(ref_floor_by_height, floor_by_height, len_floor_by_height);

    //         var collided = false;
    //         for (colliders, 0..) |collision_map, i| {
    //             if (collision_map & mover_bitmask == 0) {
    //                 if (collided)
    //                     break :not_it;

    //                 if (bapi.ByondValue_IsNull(floor_by_height[i]))
    //                     continue;

    //                 floor = floor_by_height[i];
    //             }

    //             if (bapi.ByondValue_IsNull(floor_by_height[i]))
    //                 continue;

    //             if (collision_map & (mover_bitmask >> mover_max_height_adjust) == 0) {
    //                 // TODO handling for steps larger than 1
    //                 std.debug.assert(@TypeOf(mover_max_height_adjust) == comptime_int and mover_max_height_adjust == 1);
    //                 mover_bitmask >>= mover_max_height_adjust;
    //                 mover_max_height_adjust = 0;
    //                 collided = true;
    //                 continue;
    //             }
    //             // wow, nice, complete overlap
    //             break :overlap_check; // means we can skip checking everything else
    //         }
    //     } else if (!bapi.ByondValue_IsNull(ref_floor_by_height)) not_it: {
    //         // most common scenario: regular ass turf; collision check is just overlap
    //         @branchHint(.likely);
    //         floor = ref_floor_by_height;
    //         if (turf_zebra_bitmask & mover_bitmask == 0)
    //             break :not_it;

    //         if (turf_zebra_bitmask & (mover_bitmask >> mover_max_height_adjust) != 0) {
    //             move_succeeded = false;
    //             break :overlap_check;
    //         }
    //         // TODO handling for steps larger than 1
    //         std.debug.assert(@TypeOf(mover_max_height_adjust) == comptime_int and mover_max_height_adjust == 1);
    //         mover_bitmask >>= mover_max_height_adjust;
    //         mover_max_height_adjust = 0;
    //     } else {
    //         // abyss/chasm/whatever you wanna call it
    //         // we dont actually do anything here, this is just for the branch hint
    //         @branchHint(.cold);
    //     }

    //     // then the movables
    //     _ = bapi.Byond_ReadVarByStrId(&target_turf, sref.contents, &var_ref);
    //     const contents_len: bapi.u4c = undefined;
    //     _ = bapi.Byond_ReadList(&var_ref, null, &contents_len);
    //     const ref_contents: [contents_len]bapi.ByondValue = undefined;
    //     _ = bapi.Byond_ReadList(&var_ref, &ref_contents, &contents_len);

    //     //const LAYER_STRUCT = struct {
    //     //    ref: bapi.ByondValue,
    //     //    layer: f32,
    //     //};
    //     //var struct_contents: [contents_len]LAYER_STRUCT = undefined;
    //     //for (ref_contents, 0..) |value, i| {
    //     //    _ = bapi.Byond_ReadVarByStrId(value, str_refs.layer.?, &var_ref);
    //     //    struct_contents[i] = .{ .ref = value, .layer = bapi.ByondValue_GetNum(&var_ref) };
    //     //}

    //     //const sort_fn = struct {
    //     //    fn sort_fn(lhs: LAYER_STRUCT, rhs: LAYER_STRUCT) bool {
    //     //        return lhs.layer < rhs.layer;
    //     //    }
    //     //}.sort_fn;
    //     //
    //     //std.mem.reverse(bapi.ByondValue, struct_contents); // reverse so that in case of ties, the objs that enter last have priority
    //     //std.mem.sort(bapi.ByondValue, struct_contents, {}, sort_fn); // sort by layer

    //     // nab the individual collision masks from the movables
    //     for (ref_contents) |atom_ref| {
    //         _ = bapi.Byond_ReadVarByStrId(atom_ref, sref.collision_flags, var_ref);
    //         const collision_flags = @trunc(bapi.ByondValue_GetNum(var_ref));
    //         if (collision_flags & (COLLISION.NOCLIP | COLLISION.PASS_THROUGH) != 0) //lets not cockblock ppl through admeme fuckery
    //             continue;

    //         const collision = extract_bitfield_movable(atom_ref);
    //         if (collision & mover_bitmask == 0)
    //             continue;

    //         if (mover_max_height_adjust != 0) {
    //             if (collision & (mover_bitmask >> mover_max_height_adjust) == 0) {
    //                 // TODO handling for steps larger than 1
    //                 std.debug.assert(@TypeOf(mover_max_height_adjust) == comptime_int and mover_max_height_adjust == 1);
    //                 mover_bitmask >>= mover_max_height_adjust;
    //                 mover_max_height_adjust = 0;
    //             }
    //             continue;
    //         }
    //         move_succeeded = false;
    //         bumped = atom_ref;
    //     }
    // };

    // // TODO finish
    // if (!move_succeeded) {
    //     var result: bapi.ByondValue = undefined;
    //     _ = bapi.Byond_CallProcByStrId(bumped, sref.proc_bump, mover, 1, &result);
    //     _ = bapi.ByondValue_SetNum(&result, 0);
    //     return result;
    // } else {}
}
