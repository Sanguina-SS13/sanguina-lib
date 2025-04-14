const std = @import("std");
const bapi = @import("raw/_byondapi_raw.zig");
const zig = @import("../global/core.zig");
const world = @import("world.zig");

const allocator = zig.local_alloc;

pub const ByondValueRaw = bapi.CByondValue;
pub const ValueTag = bapi.ByondValueType;
pub const RefID = bapi.u4c;

pub const HashXYZ = struct { x: c_short, y: c_short, z: c_short };
pub const ByondXYZ = struct {
    inner: bapi.CByondXYZ,

    pub fn hashKey(self: ByondXYZ) HashXYZ {
        return .{
            .x = self.inner.x,
            .y = self.inner.y,
            .z = self.inner.z,
        };
    }
};
pub const ByondPixLoc = bapi.CByondPixLoc;

pub const ByondValue = struct {
    inner: ByondValueRaw = undefined,

    /// Fills a ByondValueRaw struct with a null value.
    pub fn clear(self: *ByondValue) *ByondValue {
        bapi.ByondValue_Clear(&self.inner);
        return self;
    }

    /// Equivalent to calling /proc/length()
    pub fn length(self: ByondValue) ByondValue {
        var ret: ByondValue = undefined;
        if (!bapi.Byond_Length(&self.inner, &ret.inner))
            crash();
        return ret;
    }
    pub fn refCount(self: ByondValue) bapi.u4c {
        var ret: bapi.u4c = undefined;
        if (!bapi.Byond_Refcount(&self.inner, &ret))
            crash();
        return ret;
    }
    pub fn getXYZ(self: ByondValue) ByondXYZ {
        var ret: ByondXYZ = undefined;
        if (!bapi.Byond_XYZ(&self.inner, &ret.inner))
            crash();
        return ret;
    }
    pub fn pixLoc(self: ByondValue) ByondPixLoc {
        var ret: ByondPixLoc = undefined;
        if (!bapi.Byond_PixLoc(&self.inner, &ret))
            crash();
        return ret;
    }
    pub fn boundsPixLoc(self: ByondValue, dir: bapi.u1c) ByondPixLoc {
        var ret: ByondPixLoc = undefined;
        if (!bapi.Byond_BoundPixLoc(&self.inner, dir, &ret))
            crash();
        return ret;
    }

    // These do what you think they do.
    pub fn isNull(self: ByondValue) bool {
        return bapi.ByondValue_IsNull(&self.inner);
    }
    pub fn isNum(self: ByondValue) bool {
        return bapi.ByondValue_IsNum(&self.inner);
    }
    pub fn isStr(self: ByondValue) bool {
        return bapi.ByondValue_IsStr(&self.inner);
    }
    pub fn isList(self: ByondValue) bool {
        return bapi.ByondValue_IsList(&self.inner);
    }
    pub fn isTrue(self: ByondValue) bool {
        return bapi.ByondValue_IsTrue(&self.inner);
    }
    pub fn equals(self: ByondValue, other: ByondValue) bool {
        return bapi.ByondValue_Equals(&self.inner, other.inner);
    }

    /// Casts to f32.
    pub fn asNum(self: ByondValue) f32 {
        return bapi.ByondValue_GetNum(&self.inner);
    }
    /// Casts to RefID.
    pub fn asRef(self: ByondValue) RefID {
        return bapi.ByondValue_GetRef(&self.inner);
    }

    pub fn writeNum(self: *ByondValue, float: f32) *ByondValue {
        bapi.ByondValue_SetNum(&self.inner, float);
        return self;
    }
    pub fn writeStr(self: *ByondValue, str: [*:0]const u8) *ByondValue {
        bapi.ByondValue_SetStr(&self.inner, str);
        return self;
    }
    pub fn writeStrByID(self: *ByondValue, str_id: RefID) *ByondValue {
        bapi.ByondValue_SetStrId(&self.inner, str_id);
        return self;
    }
    pub fn writeRef(self: *ByondValue, value_type: ValueTag, ref: RefID) *ByondValue {
        bapi.ByondValue_SetRef(&self.inner, value_type, ref);
        return self;
    }

    pub fn readVar(self: ByondValue, varname: [*:0]const u8) ByondValue {
        var ret: ByondValue = undefined;
        if (!bapi.Byond_ReadVar(&self.inner, varname, &ret.inner))
            crash();
        return ret;
    }

    pub fn readVarByID(self: ByondValue, varname_id: RefID) ByondValue {
        var ret: ByondValue = undefined;
        if (!bapi.Byond_ReadVarByStrId(&self.inner, varname_id, &ret.inner))
            crash();
        return ret;
    }

    pub fn writeVar(self: ByondValue, varname: [*:0]const u8, val: ByondValue) void {
        if (!bapi.Byond_WriteVar(&self.inner, varname, &val.inner))
            crash();
    }
    pub fn writeVarByID(self: ByondValue, var_id: RefID, val: ByondValue) void {
        if (!bapi.Byond_WriteVarByStrId(&self.inner, var_id, &val.inner))
            crash();
    }

    pub fn asList(self: ByondValue, alloc: std.mem.Allocator) []ByondValue {
        var len: bapi.u4c = undefined;
        _ = bapi.Byond_ReadList(&self.inner, null, &len); // until confirmed, assume it returns false when querying

        const list = alloc.alloc(ByondValueRaw, len) catch unreachable;
        defer alloc.free(list);

        if (!bapi.Byond_ReadList(&self.inner, list.ptr, &len))
            crash();

        var ret = alloc.alloc(ByondValue, len) catch unreachable;
        for (0..len) |i|
            ret[i].inner = list[i];

        return ret;
    }

    pub fn writeList(self: ByondValue, data: []const ByondValueRaw) ByondValue {
        if (!bapi.Byond_WriteList(&self.inner, &data, data.len))
            crash();
        return self;
    }

    pub fn asAssoc(self: ByondValue, alloc: std.mem.Allocator) std.HashMap {
        var len: bapi.u4c = undefined;
        _ = bapi.Byond_ReadList(&self, null, &len); // until confirmed, assume it returns false when querying

        var list = alloc.alloc(ByondValueRaw, len) catch unreachable;
        defer alloc.free(list);

        if (!bapi.Byond_ReadListAssoc(&self, &list, &len))
            crash();

        var ret: std.AutoHashMap(ByondValue, ByondValue) = .init(alloc);
        for (0..(list.len >> 1)) |i| {
            try ret.putNoClobber(list[i * 2], list[i * 2 + 1]);
        }

        return ret;
    }

    pub fn at(self: ByondValue, index: ByondValue) ByondValue {
        var ret: ByondValue = undefined;
        if (!bapi.Byond_ReadListIndex(&self.inner, &index.inner, &ret.inner))
            crash();
        return ret;
    }

    pub fn writeAt(self: ByondValue, index: ByondValue, value: ByondValue) void {
        if (!bapi.Byond_WriteListIndex(&self.inner, &index.inner, &value.inner))
            crash();
    }

    pub fn readPointer(self: ByondValue) ByondValue {
        var ret: ByondValue = undefined;
        if (!bapi.Byond_ReadPointer(&self.inner, &ret.inner))
            crash();
        return ret;
    }

    pub fn writePointer(self: *ByondValue, value: ByondValue) void {
        if (!bapi.Byond_WritePointer(&self.inner, &value.inner))
            crash();
    }

    pub fn toString(self: ByondValue, alloc: std.mem.Allocator) []u8 {
        var len: bapi.u4c = undefined;
        _ = bapi.Byond_ToString(&self.inner, null, &len);

        const string = alloc.alloc(u8, len) catch unreachable;
        if (!bapi.Byond_ToString(&self.inner, string.ptr, &len))
            crash();
        return string;
    }

    pub fn call(self: ByondValue, name: [*:0]const u8, args: ?[]const ByondValueRaw) ByondValue {
        var ret: ByondValueRaw = ByondValue.clear();
        if (args == null) {
            if (!bapi.Byond_CallProc(&self, name, null, 0, &ret))
                crash();
            return ret;
        }

        const args_val = args.?;
        if (!bapi.Byond_CallProc(&self, name, &args_val, args_val.len, &ret))
            crash();
        return ret;
    }

    pub fn callByID(self: ByondValue, str_id: RefID, args: ?[]const ByondValueRaw) ByondValue {
        var ret: ByondValue = undefined;
        if (args == null) {
            if (!bapi.Byond_CallProcByStrId(&self.inner, str_id, null, 0, &ret.inner))
                crash();
            return ret;
        }

        const args_val = args.?;
        if (!bapi.Byond_CallProcByStrId(&self.inner, str_id, args_val.ptr, @intCast(args_val.len), &ret.inner))
            crash();
        return ret;
    }

    pub fn callSrcless(self: ByondValue, proc_name: []const u8, args: ?[]const ByondValueRaw) ByondValue {
        const floor_type = self.toString(zig.local_alloc);
        defer zig.local_alloc.free(floor_type);

        const proc = std.mem.concatWithSentinel(zig.local_alloc, u8, &[_][]const u8{ floor_type, "::", proc_name, "()" }, 0) catch unreachable;
        defer zig.local_alloc.free(proc);

        return callGlobal(proc, args);
    }

    pub fn incRef(self: ByondValue) ByondValue {
        bapi.ByondValue_IncRef(&self.inner);
        return self;
    }
    pub fn decRef(self: ByondValue) ByondValue {
        bapi.ByondValue_DecRef(&self.inner);
        return self;
    }
    pub fn decTempRef(self: ByondValue) ByondValue {
        bapi.ByondValue_DecTempRef(&self.inner);
        return self;
    }
    pub fn testRef(self: ByondValue) bool {
        return bapi.Byond_TestRef(&self.inner);
    }
};

// ---------- CREATION ----------

/// Returns a ByondValue struct representing a null. How is that different from clear()?
/// Idk, but in absence of evidence, I'll assume that one does some ref cleanup or such.
pub fn getNull() ByondValue {
    return ByondValue{
        .inner = .{
            .type = .Null,
            .data = undefined,
        },
    };
}
/// Returns a ByondValue struct representing a number.
pub fn getNumber(num: f32) ByondValue {
    return ByondValue{
        .inner = .{
            .type = .Number,
            .data = .{ .num = num },
        },
    };
}

/// Returns a ByondValue struct representing a newly made list.
pub fn createList() ByondValue {
    var ret: ByondValueRaw = undefined;
    if (!bapi.Byond_CreateList(&ret))
        crash();
    return ret;
}

pub fn new(instantiated_type: ByondValue, args_or_null: ?[]const ByondValueRaw) ByondValue {
    var ret: ByondValue = undefined;
    if (args_or_null == null) {
        if (!bapi.Byond_New(&instantiated_type.inner, null, 0, &ret.inner))
            crash();
        return ret;
    }
    const args = args_or_null.?;
    if (!bapi.Byond_New(&instantiated_type.inner, args.ptr, @intCast(args.len), &ret.inner))
        crash();
    return ret;
}

pub const getStrId = bapi.Byond_GetStrId;
pub const getStrIdOrCreate = bapi.Byond_AddGetStrId;

pub fn callGlobal(name: [*:0]const u8, args: ?[]const ByondValueRaw) ByondValue {
    var ret: ByondValue = undefined;
    if (args == null) {
        if (!bapi.Byond_CallGlobalProc(name, null, 0, &ret.inner))
            crash();
        return ret;
    }

    const args_val = args.?;
    if (!bapi.Byond_CallGlobalProc(name, args_val.ptr, @intCast(args_val.len), &ret.inner))
        crash();

    return ret;
}

pub fn callGlobalByID(str_id: RefID, args: ?[]const ByondValueRaw) ByondValue {
    var ret: ByondValue = undefined;
    if (args == null) {
        if (!bapi.Byond_CallGlobalProcByStrId(str_id, null, 0, &ret.inner))
            crash();
        return ret;
    }

    const args_val = args.?;
    if (!bapi.Byond_CallGlobalProcByStrId(str_id, args_val.ptr, @intCast(args_val.len), &ret.inner))
        crash();
    return ret;
}

// ---------- LOCATING SHIT ----------

/// Fetches a block of atoms via block().
pub fn block(corner1: ByondXYZ, corner2: ByondXYZ, alloc: std.mem.Allocator) []ByondValue {
    var arr_len: bapi.u4c = undefined;
    _ = bapi.Byond_Block(corner1.inner, corner2.inner, null, &arr_len);

    var arr = try alloc.alloc(ByondValueRaw, arr_len);
    defer alloc.free(arr);

    if (!bapi.Byond_Block(corner1.inner, corner2.inner, &arr, &arr_len))
        crash();

    var ret = try alloc.alloc(ByondValue, arr_len);
    for (0..arr_len) |i| {
        ret[i].inner = arr[i];
    }

    return ret;
}

/// Fetches an atom from a container. Equivalent to var/type/x = locate() in container;
pub fn locateIn(searched_type: ByondValue, searched_in: ByondValue) ByondValue {
    var ret: ByondValue = undefined;
    if (!bapi.Byond_LocateIn(searched_type.inner, searched_in.inner, &ret.inner))
        crash();
    return ret;
}

/// Fetches a global reference. Equivalent to var/x = locate("tag");
pub fn locateGlobal(searched_type: ByondValue) ByondValue {
    var ret: ByondValue = undefined;
    if (!bapi.Byond_LocateIn(&searched_type.inner, null, &ret.inner))
        crash();
    return ret;
}

/// Fetches a turf by coordinates. Equivalent to var/x = locate(x, y, z);
pub fn locateXYZ(xyz: ByondXYZ) ByondValue {
    var ret: ByondValue = undefined;
    if (!bapi.Byond_LocateXYZ(xyz.inner, &ret))
        crash();
    return ret;
}

// ---------- ERROR HANDLING ----------

pub const lastError = bapi.Byond_LastError;
fn _crash(message: [*:0]const u8) noreturn {
    // free local memory
    _ = zig.arena.reset(.retain_capacity);
    bapi.Byond_CRASH(message);
}

/// Throws a runtime error with the last detected error on the server side.
pub fn crash() noreturn {
    return _crash(lastError());
}

/// Throws a custom runtime error on the server side.
pub fn crashMsg(message: [*:0]const u8) noreturn {
    return _crash(message);
}

// ---------- MISC ----------

pub const threadSync = bapi.Byond_ThreadSync;

pub const getDMBVersion = bapi.Byond_GetDMBVersion;
pub fn getVersion() struct { version: bapi.u4c, build: bapi.u4c } {
    var version: bapi.u4c = undefined;
    var build: bapi.u4c = undefined;

    bapi.Byond_GetVersion(&version, &build);
    return .{ version, build };
}
