const bapi = @import("../byondapi/_byondapi.zig");
const core = @import("../global/core.zig");
const collision = @import("../byondapi/collision.zig");

// pub fn on_movable_new(_movable: bapi.ByondValueRaw) bapi.ByondValueRaw {
//     const movable = bapi.ByondValue{_movable};
//     const coords = movable.getXYZ();
//
//     const movable_list = collision.collision_map.items[coords.inner.y];
// }
//
// pub fn on_movable_del(_atom: bapi.ByondValueRaw) bapi.ByondValueRaw {
//     const atom = bapi.ByondValue{_atom};
// }
