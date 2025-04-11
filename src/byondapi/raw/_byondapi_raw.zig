pub const u1c = u8;
pub const s1c = i8;
pub const u2c = c_ushort;
pub const s2c = c_short;
pub const u4c = c_uint;
pub const s4c = c_int;
pub const s8c = c_longlong;
pub const u8c = c_ulonglong;

pub const NONE = @import("std").math.maxInt(u2c); //ALMOST no std. ALMOST.

pub const u4cOrPointer = extern union {
    num: u4c,
    ptr: ?*anyopaque,
};

pub const ByondValueType = enum(u1c) {
    Null = 0x00,
    Turf = 0x01,
    Obj = 0x02,
    Mob = 0x03,
    Area = 0x04,
    Client = 0x05,
    String = 0x06,
    // ? = 0x07,
    MobTypepath = 0x08,
    ObjTypepath = 0x09,
    TurfTypepath = 0x0A,
    AreaTypepath = 0x0B,
    Resource = 0x0C,
    Image = 0x0D,
    World = 0x0E,
    List = 0x0F,
    ArgList = 0x10,
    // ? = 0x11
    // ? = 0x12
    // ? = 0x13
    // ? = 0x14
    // ? = 0x15
    // ? = 0x16
    MobContents = 0x17,
    TurfContents = 0x18,
    AreaContents = 0x19,
    WorldContents = 0x1A,
    MobGroup = 0x1B, // rustg doesnt have it :3
    ObjContents = 0x1C,
    // ? = 0x1D
    // ? = 0x1E
    // ? = 0x1F
    DatumTypepath = 0x20, // rustg doesnt have it :3
    Datum = 0x21,
    // ? = 0x22
    SaveFile = 0x23,
    SavefilePath = 0x24, // rustg doesnt have it :3
    // ? = 0x25
    // ? = 0x26
    // ? = 0x27
    // ? = 0x28
    Pop = 0x29,
    Number = 0x2A,
    // ? = 0x2B,
    MobVars = 0x2C,
    ObjVars = 0x2D,
    TurfVars = 0x2E,
    AreaVars = 0x2F,
    ClientVars = 0x30,
    Vars = 0x31,
    MobOverlays = 0x32,
    MobUnderlays = 0x33,
    ObjOverlays = 0x34,
    ObjUnderlays = 0x35,
    TurfOverlays = 0x36,
    TurfUnderlays = 0x37,
    AreaOverlays = 0x38,
    AreaUnderlays = 0x39,
    Appearance = 0x3A,
    // ? = 0x3B
    // ? = 0x3C
    // ? = 0x3D
    // ? = 0x3E
    ByondInt = 0x3F, // cpu/maxz/sleep_offline, some internal int value? // anyways rustg doesnt have it :3
    ImageOverlays = 0x40,
    ImageUnderlays = 0x41,
    ImageVars = 0x42,
    // ? = 0x43,
    // ? = 0x44,
    // ? = 0x45,
    // ? = 0x46,
    // ? = 0x47,
    // ? = 0x48,
    // ? = 0x49,
    // ? = 0x4A,
    TurfVisContents = 0x4B,
    ObjVisContents = 0x4C,
    MobVisContents = 0x4D,
    TurfVisLocs = 0x4E,
    ObjVisLocs = 0x4F,
    MobVisLocs = 0x50,
    WorldVars = 0x51,
    GlobalVars = 0x52,
    Filters = 0x53, // rustg doesnt have it :3
    ImageVisContents = 0x54,
};

pub const CByondValue = extern struct {
    type: ByondValueType,
    junk1: u1c = undefined,
    junk2: u1c = undefined,
    junk3: u1c = undefined,
    data: extern union {
        ref: u4c,
        num: f32,
    },
};

pub const CByondXYZ = extern struct {
    x: s2c,
    y: s2c,
    z: s2c,
    _: s2c = undefined,
};

pub const CByondPixLoc = extern struct {
    x: f32,
    y: f32,
    z: s2c,
    _: s2c = undefined,
};

pub const ByondCallback = *const fn (*anyopaque) callconv(.c) CByondValue;

/// Gets the last error from a failed call.
///
/// The result is a static string that does not need to be freed.
///
/// @return Error message
pub extern fn Byond_LastError() [*c]const u8;

/// Gets the current BYOND version
///
/// @param version Pointer to the major version number
///
/// @param build Pointer to the build number
pub extern fn Byond_GetVersion(version: *u4c, build: *u4c) void;

/// Gets the DMB version
///
/// @return Version number the .dmb was built with
pub extern fn Byond_GetDMBVersion() u4c;

/// Fills a CByondValue struct with a null value.
///
/// @param v Pointer to CByondValue
pub extern fn ByondValue_Clear(v: *CByondValue) void;

/// Reads CByondVale's 1-byte data type
/// @param v Pointer to CByondValue
/// @return Type of value
pub extern fn ByondValue_Type(v: *const CByondValue) ByondValueType;

/// @param v Pointer to CByondValue
/// @return True if value is null
pub extern fn ByondValue_IsNull(v: *const CByondValue) bool;

/// @param v Pointer to CByondValue
/// @return True if value is a numeric type
pub extern fn ByondValue_IsNum(v: *const CByondValue) bool;

/// @param v Pointer to CByondValue
/// @return True if value is a string
pub extern fn ByondValue_IsStr(v: *const CByondValue) bool;

/// @param v Pointer to CByondValue
/// @return True if value is a list (any list type, not just user-defined)
pub extern fn ByondValue_IsList(v: *const CByondValue) bool;

/// Determines if a value is logically true or false
///
/// @param v Pointer to CByondValue
/// @return Truthiness of value
pub extern fn ByondValue_IsTrue(v: *const CByondValue) bool;

/// @param v Pointer to CByondValue
/// @return Floating point number for v, or 0 if not numeric
pub extern fn ByondValue_GetNum(v: *const CByondValue) f32;

/// @param v Pointer to CByondValue
/// @return Reference ID if value is a reference type, or 0 otherwise
pub extern fn ByondValue_GetRef(v: *const CByondValue) u4c;

/// Fills a CByondValue struct with a floating point number.
/// @param v Pointer to CByondValue
/// @param f Floating point number
pub extern fn ByondValue_SetNum(v: *CByondValue, f: f32) void;

/// Creates a string and sets CByondValue to a reference to that string, and increases the reference count. See REFERENCE COUNTING in byondapi.h.
/// Blocks if not on the main thread. If string creation fails, the struct is set to null.
/// @param v Pointer to CByondValue
/// @param str Null-terminated UTF-8 string
/// @see Byond_AddGetStrId()
pub extern fn ByondValue_SetStr(v: *CByondValue, str: [*:0]const u8) void;

/// Fills a CByondValue struct with a reference to a string with a given ID. Does not validate, and does not increase the reference count.
/// If the strid is NONE, it will be changed to 0.
/// @param v Pointer to CByondValue
/// @param strid 4-byte string ID
/// @see Byond_TestRef()
pub extern fn ByondValue_SetStrId(v: *CByondValue, strid: u4c) void;

/// Fills a CByondValue struct with a reference (object) type. Does not validate.
/// @param v Pointer to CByondValue
/// @param type 1-byte teference type
/// @param ref 4-byte reference ID; for most types, an ID of NONE is invalid
/// @see Byond_TestRef()
pub extern fn ByondValue_SetRef(v: *CByondValue, type: ByondValueType, ref: u4c) void;

/// Compares two values for equality
/// @param a Pointer to CByondValue
/// @param b Pointer to CByondValue
/// @return True if values are equal
pub extern fn ByondValue_Equals(a: *const CByondValue, b: *const CByondValue) bool;

// In the following functions, anything that fills a result value (e.g.,
// ReadVar, CallProc) will create a reference to the value. See REFERENCE
// COUNTING below for more details.
//
// In general, if you're not creating any threads of your own and you
// don't need to save a reference for later, you don't need to worry about
// reference counting. The main thread uses temporary references that will
// clean themselves up at tick's end.
// If the validity of a reference is ever in doubt, call Byond_TestRef().
//
// THREAD SAFETY:
//
// Anything called outside of the main thread will block, unless otherwise
// noted.
//
// Also note that references created outside the main thread are always
// persistent, and must be cleaned up with ByondValue_DecRef().

/// Runs a function as a callback on the main thread (or right away if already there).
/// All references created from Byondapi calls within your callback are persistent, not temporary, even though your callback runs on the main thread.
///
/// Blocking is optional. If already on the main thread, the block parameter is meaningless.
///
/// @param callback Function pointer to CByondValue function(void*)
///
/// @param data Void pointer (argument to function)
///
/// @param block True if this call should block while waiting for the callback to finish; false if not
///
/// @return CByondValue returned by the function (if it blocked; null if not)
pub extern fn Byond_ThreadSync(callback: ByondCallback, data: ?*anyopaque, block: bool) ?CByondValue;

/// Returns a reference to an existing string ID, but does not create a new string ID.
/// Blocks if not on the main thread.
/// @param str Null-terminated string
/// @return ID of string; NONE if string does not exist
pub extern fn Byond_GetStrId(str: [*:0]const u8) u4c; // does not add a string to the tree if not found; returns NONE if no string match

/// Returns a reference to an existing string ID or creates a new string ID reference.
/// The new string is reference-counted. See REFERENCE COUNTING in byondapi.h for details.
/// Call ByondValue_SeStrId() to use the returned ID in a CByondValue.
/// Blocks if not on the main thread.
/// @param str Null-terminated string
/// @return ID of string; NONE if string creation failed
pub extern fn Byond_AddGetStrId(str: [*:0]const u8) u4c; // adds a string to the tree if not found

/// Reads an object variable by name.
/// Blocks if not on the main thread.
/// @param loc Object that owns the var
/// @param varname Var name as null-terminated string
/// @param result Pointer to accept result
/// @return True on success
pub extern fn Byond_ReadVar(loc: *const CByondValue, varname: [*:0]const u8, result: *CByondValue) bool;

/// Reads an object variable by the string ID of its var name.
/// ID can be cached ahead of time for performance.
/// Blocks if not on the main thread.
/// @param loc Object that owns the var
/// @param varname Var name as string ID
/// @param result Pointer to accept result
/// @return True on success
/// @see Byond_GetStrId()
pub extern fn Byond_ReadVarByStrId(loc: *const CByondValue, varname: u4c, result: *CByondValue) bool;

/// Writes an object variable by name.
/// Blocks if not on the main thread.
/// @param loc Object that owns the var
/// @param varname Var name as null-terminated string
/// @param val New value
/// @return True on success
pub extern fn Byond_WriteVar(loc: *const CByondValue, varname: [*:0]const u8, val: *const CByondValue) bool;

/// Writes an object variable by the string ID of its var name.
/// ID can be cached ahead of time for performance.
/// Blocks if not on the main thread.
/// @param loc Object that owns the var
/// @param varname Var name as string ID
/// @param val New value
/// @return True on success
pub extern fn Byond_WriteVarByStrId(loc: *const CByondValue, varname: u4c, val: *const CByondValue) bool;

/// Creates an empty list with a temporary reference. Equivalent to list().
/// Blocks if not on the main thread.
/// @param result Result
/// @return True on success
pub extern fn Byond_CreateList(result: *CByondValue) bool;

/// Reads items from a list.
/// Blocks if not on the main thread.
/// @param loc The list to read
/// @param list CByondValue array, allocated by caller (can be null if querying length)
/// @param len Pointer to length of array (in items); receives the number of items read on success, or required length of array if not big enough
/// @return True on success; false with *len=0 for failure; false with *len=required size if array is not big enough
pub extern fn Byond_ReadList(loc: *const CByondValue, list: ?[*]CByondValue, len: *u4c) bool;

/// Writes items to a list, in place of old contents.
/// Blocks if not on the main thread.
/// @param loc The list to fill
/// @param list CByondValue array of items to write
/// @param len Number of items to write
/// @return True on success
pub extern fn Byond_WriteList(loc: *const CByondValue, list: [*]CByondValue, len: u4c) bool;

/// Reads items as key,value pairs from an associative list, storing them sequentially as key1, value1, key2, value2, etc.
/// Blocks if not on the main thread.
/// @param loc The list to read
/// @param list CByondValue array, allocated by caller (can be null if querying length)
/// @param len Pointer to length of array (in items); receives the number of items read on success, or required length of array if not big enough
/// @return True on success; false with *len=0 for failure; false with *len=required size if array is not big enough
pub extern fn Byond_ReadListAssoc(loc: *const CByondValue, list: ?[*]CByondValue, len: *u4c) bool;

/// Reads an item from a list.
/// Blocks if not on the main thread.
/// @param loc The list
/// @param idx The index in the list (may be a number, or a non-number if using associative lists)
/// @param result Pointer to accept result
/// @return True on success
pub extern fn Byond_ReadListIndex(loc: *const CByondValue, idx: *const CByondValue, result: *CByondValue) bool;

/// Writes an item to a list. Blocks if not on the main thread.
///
/// @param loc The list
/// @param idx The index in the list (may be a number, or a non-number if using associative lists)
/// @param val New value
/// @return True on success
pub extern fn Byond_WriteListIndex(loc: *const CByondValue, idx: *const CByondValue, val: *const CByondValue) bool;

/// Reads from a BYOND pointer. Blocks if not on the main thread.
///
/// @param ptr The BYOND pointer
/// @param result Pointer to accept result
/// @return True on success
pub extern fn Byond_ReadPointer(ptr: *const CByondValue, result: *CByondValue) bool;

/// Writes to a BYOND pointer. Blocks if not on the main thread.
///
/// @param ptr The BYOND pointer
/// @param val New value
/// @return True on success
pub extern fn Byond_WritePointer(ptr: *const CByondValue, val: *const CByondValue) bool;

// Proc calls:
//
// arg is an array of arguments; can be null arg_count is 0.
//
// The call is implicitly a waitfor=0 call; if the callee sleeps it will return
// immediately and finish later.

/// Calls an object proc by name.
/// The proc call is treated as waitfor=0 and will return immediately on sleep.
/// Blocks if not on the main thread.
/// @param src The object that owns the proc
/// @param name Proc name as null-terminated string
/// @param arg Array of arguments
/// @param arg_count Number of arguments
/// @param result Pointer to accept result
/// @return True on success
pub extern fn Byond_CallProc(src: *const CByondValue, name: [*:0]const u8, arg: ?[*]const CByondValue, arg_count: u4c, result: *CByondValue) bool;

/// Calls an object proc by name, where the name is a string ID.
/// The proc call is treated as waitfor=0 and will return immediately on sleep.
/// Blocks if not on the main thread.
/// @param src The object that owns the proc
/// @param name Proc name as string ID
/// @param arg Array of arguments
/// @param arg_count Number of arguments
/// @param result Pointer to accept result
/// @return True on success
/// @see Byond_GetStrId()
pub extern fn Byond_CallProcByStrId(src: *const CByondValue, name: u4c, arg: ?[*]const CByondValue, arg_count: u4c, result: *CByondValue) bool;

/// Calls a global proc by name.
/// The proc call is treated as waitfor=0 and will return immediately on sleep.
/// Blocks if not on the main thread.
/// @param name Proc name as null-terminated string
/// @param arg Array of arguments
/// @param arg_count  Number of arguments
/// @param result Pointer to accept result
/// @return True on success
pub extern fn Byond_CallGlobalProc(name: [*:0]const u8, arg: ?[*]const CByondValue, arg_count: u4c, result: *CByondValue) bool; // result MUST be initialized first!

/// Calls a global proc by name, where the name is a string ID.
/// The proc call is treated as waitfor=0 and will return immediately on sleep.
/// Blocks if not on the main thread.
/// @param name Proc name as string ID
/// @param arg Array of arguments
/// @param arg_count Number of arguments
/// @param result Pointer to accept result
/// @return True on success
/// @see Byond_GetStrId()
pub extern fn Byond_CallGlobalProcByStrId(name: u4c, arg: ?[*]const CByondValue, arg_count: u4c, result: *CByondValue) bool; // result MUST be initialized first!

/// Uses BYOND's internals to represent a value as text
/// Blocks if not on the main thread.
/// @param src The value to convert to text
/// @param buf char array, allocated by caller (can be null if querying length)
/// @param buflen Pointer to length of array in bytes; receives the string length (including trailing null) on success, or required length of array if not big enough
/// @return True on success; false with *buflen=0 for failure; false with *buflen=required size if array is not big enough
pub extern fn Byond_ToString(src: *const CByondValue, buf: ?[*]u8, buflen: *u4c) bool;

// Other builtins

/// Equivalent to calling block(x1,y1,z1, x2,y2,z2).
/// Blocks if not on the main thread.
/// @param corner1 One corner of the block
/// @param corner2 Another corner of the block
/// @param list CByondValue array, allocated by caller (can be null if querying length)
/// @param len Pointer to length of array (in items); receives the number of items read on success, or required length of array if not big enough
/// @return True on success; false with *len=0 for failure; false with *len=required size if array is not big enough
pub extern fn Byond_Block(corner1: *const CByondXYZ, corner2: *const CByondXYZ, list: ?[*]CByondValue, len: *u4c) bool;

/// Equivalent to calling length(value).
/// Blocks if not on the main thread.
pub extern fn Byond_Length(src: *const CByondValue, result: *CByondValue) bool;

/// Equivalent to calling locate(type), or locate(type) in list.
/// Blocks if not on the main thread.
/// @param type The type to locate
/// @param list The list to locate in; can be a null pointer instead of a CByondValue to locate(type) without a list
/// @param result Pointer to accept result; can be null if nothing is found
/// @return True on success (including if nothing is found); false on error
pub extern fn Byond_LocateIn(@"type": *const CByondValue, list: ?*const CByondValue, result: *CByondValue) bool;

/// Equivalent to calling locate(x,y,z)
/// Blocks if not on the main thread.
/// Result is null if coords are invalid.
/// @param xyz The x,y,z coords
/// @param result Pointer to accept result
/// @return True (always)
pub extern fn Byond_LocateXYZ(xyz: *const CByondXYZ, result: *CByondValue) bool;

/// Equivalent to calling new type(...)
/// Blocks if not on the main thread.
/// @param type The type to create (type path or string)
/// @param arg Array of arguments
/// @param arg_count Number of arguments
/// @param result Pointer to accept result
/// @return True on success
pub extern fn Byond_New(@"type": *const CByondValue, arg: ?[*]const CByondValue, arg_count: u4c, result: *CByondValue) bool;

/// Equivalent to calling new type(arglist)
/// Blocks if not on the main thread.
/// @param type The type to create (type path or string)
/// @param arglist Arguments, as a reference to an arglist
/// @param result Pointer to accept result
/// @return True on success
pub extern fn Byond_NewArglist(@"type": *const CByondValue, arglist: *const CByondValue, result: *CByondValue) bool; // result MUST be initialized first!

/// Equivalent to calling refcount(value)
/// Blocks if not on the main thread.
/// @param src The object to refcount
/// @param result Pointer to accept result
/// @return True on success
pub extern fn Byond_Refcount(src: *const CByondValue, result: *u4c) bool; // result MUST be initialized first!

/// Get x,y,z coords of an atom
/// Blocks if not on the main thread.
/// @param src The object to read
/// @param xyz Pointer to accept CByondXYZ result
/// @return True on success
pub extern fn Byond_XYZ(src: *const CByondValue, xyz: *CByondXYZ) bool; // still returns true if the atom is off-map, but xyz will be 0,0,0

/// Get pixloc coords of an atom
/// Blocks if not on the main thread.
/// @param src The object to read
/// @param pixloc Pointer to accept CByondPixLoc result
/// @return True on success
pub extern fn Byond_PixLoc(src: *const CByondValue, pixloc: *CByondPixLoc) bool; // still returns true if the atom is off-map, but pixloc will be 0,0,0

/// Get pixloc coords of an atom based on its bounding box
/// Blocks if not on the main thread.
/// @param src The object to read
/// @param dir The direction
/// @param pixloc Pointer to accept CByondPixLoc result
/// @return True on success
pub extern fn Byond_BoundPixLoc(src: *const CByondValue, dir: u1c, pixloc: *CByondPixLoc) bool; // still returns true if the atom is off-map, but pixloc will be 0,0,0

// REFERENCE COUNTING
//
// BYOND uses reference counting internally with IncRefCount() and
// DecRefCount() functions, so when an object runs out of references it will
// be garabge-collected. Byondapi keeps a separate reference count for
// temporary and persistent references.
//
// Results from most Byondapi calls, for instance the value that will be
// stored in the result pointer for Byond_ReadVar(), are refcounted.
//
// Temporary references are made when you call Byondapi on the main thread.
// They will be removed at the end of the current server tick. You can call
// Byond_IncRef() to make a persistent reference if you need to hold onto it
// for longer. You can also get rid of a temporary reference right away by
// calling ByondValue_DecTempRef(), which might trigger garbage collection if
// the object is no longer used.
//
// Byondapi calls made from other threads, OR during a Byond_ThreadSync()
// callback, create persistent references. Persistent references last until you
// call ByondValue_DecRef(). Calling ByondValue_IncRef() will also increase the
// persistent reference count.
//
// You MUST remember to call ByondValue_DecRef() to clean up any persistent
// references. Otherwise the objects will remain in memory until you call del()
// on them or the world reboots.
//
// NOTES:
//
// These only apply to refcounted types, not null or num. Any runtime errors
// that might happen when an object is garbage-collected as a result of
// ByondValue_DecRef() or ByondValue_DecTempRef() are ignored.
//
// Turfs are not refcounted in BYOND. Please note that whenever you resize
// the map, turf references change. For this reason, if you have a reference
// to a turf you're better off storing it as CByondXYZ coordinates instead.
//
// Calling del() from within BYOND will scan Byondapi's references and remove
// them. Any CByondValue structures you have in your library will not be
// cleared or changed by a garbage scan; they will simply become invalid.
//
// Byond_ThreadSync() is an exception to the temporary reference rule. When
// you call Byond_ThreadSync(), the callback function you supply will be called
// on BYOND's main thread, but any references created in Byondapi calls during
// that callback will be persistent. The reason for this is hopefully obvious:
// The only reason you'd call this function at all is because you're working
// with multiple threads and you would want all references to persist.

/// Increase the persistent reference count of an object used in Byondapi.
/// Blocks if not on the main thread.
///
/// Reminder: Calls only create temporary references when made on the main thread. On other threads, the references are already persistent.
/// @param src The object to incref
pub extern fn ByondValue_IncRef(src: *const CByondValue) void;

/// Mark a persistent reference as no longer in use by Byondapi.
/// This is IMPORTANT to call when you make Byondapi calls on another thread, since all the references they create are persistent.
///
/// This cannot be used for temporary references. See ByondValue_DecTempRef() for those.
///
/// Blocks if not on the main thread.
///
/// @param src The object to decref
pub extern fn ByondValue_DecRef(src: *const CByondValue) void;

/// Mark a temporary reference as no longer in use by Byondapi
/// Temporary references will be deleted automatically at the end of a tick, so this only gets rid of the reference a little faster.
/// Only works on the main thread. Does nothing on other threads.
/// @param src The object to decref
pub extern fn ByondValue_DecTempRef(src: *const CByondValue) void;

/// Test if a reference-type CByondValue is valid
/// Blocks if not on the main thread.
/// @param src Pointer to the reference to test; will be filled with null if the reference is invalid
/// @return True if ref is valid; false if not
///
/// Returns true if the ref is valid.
/// Returns false if the ref was not valid and had to be changed to null.
/// This only applies to ref types, not null/num/string which are always valid.
pub extern fn Byond_TestRef(src: *CByondValue) bool;

// Usage note for Byond_CRASH(): This will throw an exception in BYOND's server
// code which is caught like any other runtime error. It will NOT do any stack
// unwinding in the external library that calls it, so destructors and catch
// blocks will not be called.
//
// Best practice for using this function is to call it outside of a scope where
// any destructors might be needed.

/// Causes a runtime error to crash the current proc
/// Blocks if not on the main thread.
/// @param message Message to use as the runtime error
pub extern fn Byond_CRASH(message: [*:0]const u8) noreturn;
