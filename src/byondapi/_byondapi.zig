const std = @import("std");
const bapi = @import("raw/_byondapi_raw.zig");
const zig = @import("../defines/zig.zig");

const allocator = zig.local_alloc;

pub const ByondValueRaw = bapi.CByondValue;
pub const ValueTag = bapi.ByondValueType;
pub const RefID = bapi.u4c;

pub const ByondXYZ = bapi.CByondXYZ;
pub const ByondPixLoc = bapi.CByondPixLoc;

pub const ByondValue = struct {
    inner: ByondValueRaw = undefined,

    /// Fills a CByondValue struct with a null value.
    pub fn clear(self: *ByondValue) ByondValue {
        bapi.ByondValue_Clear(self);
        return self;
    }
    /// Equivalent to calling /proc/length()
    pub fn length(self: *ByondValue) ByondValue {
        var ret: ByondValue = undefined;
        bapi.Byond_Length(self, &ret.inner) orelse crash();
        return ret;
    }
    pub fn refCount(self: *ByondValue) bapi.u4c {
        var ret: bapi.u4c = undefined;
        bapi.Byond_Refcount(&self.inner, &ret) orelse crash();
        return ret;
    }
    pub fn getXYZ(self: *ByondValue) ByondXYZ {
        var ret: ByondXYZ = undefined;
        bapi.Byond_XYZ(&self.inner, &ret) orelse crash();
        return ret;
    }
    pub fn pixLoc(self: *ByondValue) ByondPixLoc {
        var ret: ByondPixLoc = undefined;
        bapi.Byond_PixLoc(&self.inner, &ret) orelse crash();
        return ret;
    }
    pub fn boundsPixLoc(self: *ByondValue, dir: bapi.u1c) ByondPixLoc {
        var ret: ByondPixLoc = undefined;
        bapi.Byond_BoundPixLoc(&self.inner, dir, &ret) orelse crash();
        return ret;
    }

    // These do what you think they do.
    pub fn isNull(self: *ByondValue) bool {
        return bapi.ByondValue_IsNull(self);
    }
    pub fn isNum(self: *ByondValue) bool {
        return bapi.ByondValue_IsNum(self);
    }
    pub fn isStr(self: *ByondValue) bool {
        return bapi.ByondValue_IsStr(self);
    }
    pub fn isList(self: *ByondValue) bool {
        return bapi.ByondValue_IsList(self);
    }
    pub fn isTrue(self: *ByondValue) bool {
        return bapi.ByondValue_IsTrue(self);
    }
    pub fn equals(self: *ByondValue, other: ByondValue) bool {
        return bapi.ByondValue_Equals(self, other.inner);
    }

    /// Casts to f32.
    pub fn asNum(self: *ByondValue) f32 {
        return bapi.ByondValue_GetNum(&self);
    }
    /// Casts to RefID.
    pub fn asRef(self: *ByondValue) RefID {
        return bapi.ByondValue_GetRef(&self);
    }

    pub fn writeNum(self: *ByondValue, float: f32) ByondValue {
        bapi.ByondValue_SetNum(&self, float);
        return self;
    }
    pub fn writeStr(self: *ByondValue, str: [*:0]const u8) ByondValue {
        bapi.ByondValue_SetStr(&self, str);
        return self;
    }
    pub fn writeStrByID(self: *ByondValue, str_id: RefID) ByondValue {
        bapi.ByondValue_SetStrId(&self, str_id);
        return self;
    }
    pub fn writeRef(self: *ByondValue, value_type: ValueTag, ref: RefID) ByondValue {
        bapi.ByondValue_SetRef(&self, value_type, ref);
        return self;
    }

    pub fn readVar(self: *const ByondValue, varname: [*:0]const u8) ByondValue {
        var ret: ByondValue = undefined;
        bapi.Byond_ReadVar(&self, varname, &ret.inner) orelse crash();
        return ret;
    }

    pub fn readVarByID(self: *const ByondValue, varname_id: RefID) ByondValue {
        var ret: ByondValue = undefined;
        bapi.Byond_ReadVarByStrId(&self, varname_id, &ret.inner) orelse crash();
        return ret;
    }

    pub fn writeVar(self: *const ByondValue, varname: [*:0]const u8, val: ByondValue) void {
        bapi.Byond_WriteVar(&self, varname, &val) orelse crash();
    }
    pub fn writeVarByID(self: *const ByondValue, var_id: RefID, val: ByondValue) void {
        bapi.Byond_WriteVarByStrId(&self, var_id, &val) orelse crash();
    }

    pub fn asList(self: *const ByondValue, alloc: std.mem.Allocator) []ByondValue {
        var len: bapi.u4c = undefined;
        _ = bapi.Byond_ReadList(&self, null, &len); // until confirmed, assume it returns false when querying

        var list = try alloc.alloc(ByondValueRaw, len);
        defer alloc.free(list);

        bapi.Byond_ReadList(&self, &list, &len) orelse crash();

        var ret = try alloc.alloc(ByondValue, len);
        for (0..len) |i|
            ret[i].inner = list[i];

        return ret;
    }

    pub fn writeList(self: *const ByondValue, data: []const ByondValue) ByondValue {
        var list = try allocator.alloc(ByondValueRaw, data.len);
        defer allocator.free(list);

        bapi.Byond_WriteList(&self.inner, &list, list.len) orelse crash();
        return self;
    }

    pub fn asAssoc(self: *const ByondValue, alloc: std.mem.Allocator) std.HashMap {
        var len: bapi.u4c = undefined;
        _ = bapi.Byond_ReadList(&self, null, &len); // until confirmed, assume it returns false when querying

        var list = try alloc.alloc(ByondValueRaw, len);
        defer alloc.free(list);

        bapi.Byond_ReadListAssoc(&self, &list, &len) orelse crash();

        const Context = struct {
            pub fn hash(_: @This(), K: ByondValue) u64 {
                const value = K.inner;
                const concated = (value.type << 32) + value.data.ref;
                return concated;
            }

            pub fn eql(_: @This(), a: ByondValue, b: ByondValue) bool {
                return a.inner.data == b.inner.data;
            }
        };

        var ret: std.HashMap(ByondValue, ByondValue) = .initContext(alloc, Context);
        for (0..(list.len >> 1)) |i| {
            try ret.putNoClobber(list[i * 2], list[i * 2 + 1]);
        }

        return ret;
    }

    pub fn at(self: *const ByondValue, index: ByondValue) ByondValue {
        var ret: ByondValue = undefined;
        bapi.Byond_ReadListIndex(&self, &index, &ret.inner) orelse crash();
        return ret;
    }

    pub fn writeAt(self: *const ByondValue, index: ByondValue, value: ByondValue) void {
        bapi.Byond_WriteListIndex(self, index.inner, value.inner) orelse crash();
    }

    pub fn readPointer(self: *const ByondValue) ByondValue {
        var ret: ByondValue = undefined;
        bapi.Byond_ReadPointer(self, &ret.inner) orelse crash();
        return ret;
    }

    pub fn writePointer(self: *const ByondValue, value: ByondValue) void {
        bapi.Byond_WritePointer(self, &value.inner) orelse crash();
    }

    pub fn toString(self: *const ByondValue, alloc: std.mem.Allocator) []u8 {
        var len: bapi.u4c = undefined;
        _ = bapi.Byond_ToString(&self.inner, null, &len);

        var string = try alloc.alloc(u8, len);

        bapi.Byond_ToString(&self.inner, &string, &len) orelse crash();
        return string;
    }

    pub fn call(self: *ByondValue, name: [*:0]const u8, args: ?[]ByondValue) ByondValue {
        var ret: ByondValueRaw = ByondValue.clear();
        if (args == null) {
            bapi.Byond_CallProc(self, name, null, 0, &ret) orelse crash();
            return ret;
        }

        const args_val = args.?;

        var arr = try allocator.alloc(ByondValue, args_val.len);
        defer allocator.free(arr);

        for (0..arr.len) |i| {
            arr[i] = args_val[i];
        }

        bapi.Byond_CallProc(self, name, &arr, arr.len, &ret) orelse crash();
        return ret;
    }

    pub fn callByID(self: *ByondValue, str_id: RefID, args: ?[]ByondValue) ByondValue {
        var ret: ByondValueRaw = ByondValue.clear();
        if (args == null) {
            bapi.Byond_CallProcByStrId(self, str_id, null, 0, &ret) orelse crash();
            return ret;
        }

        const args_val = args.?;

        var arr = try allocator.alloc(ByondValue, args_val.len);
        defer allocator.free(arr);

        for (0..arr.len) |i| {
            arr[i] = args_val[i];
        }

        bapi.Byond_CallProcByStrId(self, str_id, &arr, arr.len, &ret) orelse crash();
        return ret;
    }

    pub fn incRef(self: *ByondValue) void {
        bapi.ByondValue_IncRef(&self.inner);
    }
    pub fn decRef(self: *ByondValue) void {
        bapi.ByondValue_DecRef(&self.inner);
    }
    pub fn decTempRef(self: *ByondValue) void {
        bapi.ByondValue_DecTempRef(&self.inner);
    }
    pub fn testRef(self: *ByondValue) bool {
        return bapi.Byond_TestRef(&self.inner);
    }
};

pub const lastError = bapi.Byond_LastError;
pub const getDMBVersion = bapi.Byond_GetDMBVersion;
pub fn getVersion() struct { version: c_uint, build: c_uint } {
    var version: bapi.u4c = undefined;
    var build: bapi.u4c = undefined;

    bapi.Byond_GetVersion(&version, &build);
    return .{ version, build };
}

pub const threadSync = bapi.Byond_ThreadSync;

pub const getStrId = bapi.Byond_GetStrId;
pub const getStrIdOrCreate = bapi.Byond_AddGetStrId;

pub fn createList() ByondValue {
    var ret: ByondValueRaw = undefined;
    bapi.Byond_CreateList(&ret) orelse crash();
    return ret;
}

// result MUST be initialized first!
pub fn callGlobal(name: [*:0]const u8, args: ?[]const ByondValue) ByondValue {
    var ret: ByondValueRaw = ByondValue.clear();
    if (args == null) {
        bapi.Byond_CallGlobalProc(name, null, 0, &ret) orelse crash();
        return ret;
    }

    const args_val = args.?;

    var arr = try allocator.alloc(ByondValue, args_val.len);
    defer allocator.free(arr);

    for (0..arr.len) |i| {
        arr[i] = args_val[i];
    }

    bapi.Byond_CallGlobalProc(name, &arr, arr.len, &ret) orelse crash();
    return ret;
}

// result MUST be initialized first!
pub fn callGlobalByID(str_id: RefID, args: ?[]const ByondValue) ByondValue {
    var ret: ByondValueRaw = ByondValue.clear();
    if (args == null) {
        bapi.Byond_CallGlobalProcByStrId(str_id, null, 0, &ret) orelse crash();
        return ret;
    }

    const args_val = args.?;

    var arr = try allocator.alloc(ByondValue, args_val.len);
    defer allocator.free(arr);

    for (0..arr.len) |i| {
        arr[i] = args_val[i];
    }

    bapi.Byond_CallGlobalProcByStrId(str_id, &arr, arr.len, &ret) orelse crash();
    return ret;
}

pub fn block(corner1: ByondXYZ, corner2: ByondXYZ, alloc: std.mem.Allocator) []ByondValue {
    var arr_len: bapi.u4c = undefined;
    _ = bapi.Byond_Block(corner1, corner2, null, &arr_len);

    var arr = try alloc.alloc(ByondValueRaw, arr_len);
    defer alloc.free(arr);

    bapi.Byond_Block(corner1, corner2, &arr, &arr_len) orelse crash();

    var ret = try alloc.alloc(ByondValue, arr_len);
    for (0..arr_len) |i| {
        ret[i].inner = arr[i];
    }

    return ret;
}

pub fn locateIn(searched_type: ByondValue, searched_in: ByondValue) ByondValue {
    var ret: ByondValue = undefined;
    bapi.Byond_LocateIn(searched_type.inner, searched_in.inner, &ret.inner) orelse crash();
    return ret;
}

pub fn locateGlobal(searched_type: ByondValue) ByondValue {
    var ret: ByondValue = undefined;
    bapi.Byond_LocateIn(&searched_type.inner, null, &ret.inner) orelse crash();
    return ret;
}

pub fn locateXYZ(xyz: ByondXYZ) ByondValue {
    var ret: ByondValue = undefined;
    bapi.Byond_LocateXYZ(xyz, &ret) orelse crash();
    return ret;
}

pub fn new(instantiated_type: ByondValue, args_or_null: ?[]const ByondValue) ByondValue {
    var ret: ByondValue = undefined;
    if (args_or_null == null) {
        bapi.Byond_New(&instantiated_type.inner, null, 0, &ret.inner) orelse crash();
        return ret;
    }

    const args = args_or_null.?;

    var arr = try allocator.alloc(ByondValueRaw, args.len);
    defer allocator.free(arr);

    bapi.Byond_New(&instantiated_type.inner, &arr, arr.len, &ret.inner) orelse crash();
    return ret;
}

fn _crash(message: ?[*:0]const u8) noreturn {
    // free local memory
    zig.arena.reset();
    bapi.Byond_CRASH(message);
}

pub fn crash() noreturn {
    return _crash(lastError());
}

pub fn crashMsg(message: [*:0]const u8) noreturn {
    return _crash(message);
}
