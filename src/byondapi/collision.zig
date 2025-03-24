const bapi = @import("_byondapi.zig");
const sref = @import("types.zig").strRefs;

fn _import_bitfield(atom: bapi.ByondValue, comptime is_turf: bool) u72 {
    const id_a = if (is_turf) sref.turf_bitmask_a else sref.movable_bitmask_a;
    const id_b = if (is_turf) sref.turf_bitmask_b else sref.movable_bitmask_b;
    const id_c = if (is_turf) sref.turf_bitmask_c else sref.movable_bitmask_c;

    const a: u24 = @trunc(atom.readVarByID(id_a).asNum());
    const b: u24 = @trunc(atom.readVarByID(id_b).asNum());
    const c: u24 = @trunc(atom.readVarByID(id_c).asNum());

    return (a << 0) | (b << 24) | (c << 48);
}

fn _export_bitfield(atom: bapi.ByondValue, bitfield: u72, comptime is_turf: bool) void {
    const id_a = if (is_turf) sref.turf_bitmask_a else sref.movable_bitmask_a;
    const id_b = if (is_turf) sref.turf_bitmask_b else sref.movable_bitmask_b;
    const id_c = if (is_turf) sref.turf_bitmask_c else sref.movable_bitmask_c;

    const f1: f32 = @bitCast(bitfield & @as(u24, ~0));
    const f2: f32 = @bitCast((bitfield << 24) & @as(u24, ~0));
    const f3: f32 = @bitCast((bitfield << 48) & @as(u24, ~0));

    var var_a: bapi.ByondValue = undefined;
    var var_b: bapi.ByondValue = undefined;
    var var_c: bapi.ByondValue = undefined;

    atom.writeVarByID(id_a, var_a.writeNum(f1));
    atom.writeVarByID(id_b, var_b.writeNum(f2));
    atom.writeVarByID(id_c, var_c.writeNum(f3));
}

pub fn import_turfmask_bitfield(turf: bapi.ByondValue) u72 {
    return _import_bitfield(turf, true);
}
pub fn export_turfmask_bitfield(turf: bapi.ByondValue, bitfield: u72) void {
    return _export_bitfield(turf, bitfield, true);
}

pub fn import_collision_bitfield(movable: bapi.ByondValue) u72 {
    return _import_bitfield(movable, false);
}
pub fn export_collision_bitfield(movable: bapi.ByondValue, bitfield: u72) void {
    return _export_bitfield(movable, bitfield, false);
}
