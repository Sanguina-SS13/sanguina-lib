//! This file contains dummy definitions for the compiler to not trip.

const bapi = @import("byondapi");
const u4c = bapi.RefID;

pub export fn Byond_GetVersion(...) void {
    @panic("stub function Byond_GetVersion called!");
}
pub export fn Byond_GetDMBVersion() u4c {
    @panic("stub function Byond_GetDMBVersion called!");
}
pub export fn ByondValue_Clear(...) void {
    @panic("stub function ByondValue_Clear called!");
}
pub export fn ByondValue_Type(...) anyopaque {
    @panic("stub function ByondValue_Type called!");
}
pub export fn ByondValue_IsNull(...) bool {
    @panic("stub function ByondValue_IsNull called!");
}
pub export fn ByondValue_IsNum(...) bool {
    @panic("stub function ByondValue_IsNum called!");
}
pub export fn ByondValue_IsStr(...) bool {
    @panic("stub function ByondValue_IsStr called!");
}
pub export fn ByondValue_IsList(...) bool {
    @panic("stub function ByondValue_IsList called!");
}
pub export fn ByondValue_IsTrue(...) bool {
    @panic("stub function ByondValue_IsTrue called!");
}
pub export fn ByondValue_GetNum(...) f32 {
    @panic("stub function ByondValue_GetNum called!");
}
pub export fn ByondValue_GetRef(...) u4c {
    @panic("stub function ByondValue_GetRef called!");
}
pub export fn ByondValue_SetNum(...) void {
    @panic("stub function ByondValue_SetNum called!");
}
pub export fn ByondValue_SetStr(...) void {
    @panic("stub function ByondValue_SetStr called!");
}
pub export fn ByondValue_SetStrId(...) void {
    @panic("stub function ByondValue_SetStrId called!");
}
pub export fn ByondValue_SetRef(...) void {
    @panic("stub function ByondValue_SetRef called!");
}
pub export fn ByondValue_Equals(...) bool {
    @panic("stub function ByondValue_Equals called!");
}
pub export fn Byond_ThreadSync(...) ?anyopaque {
    @panic("stub function Byond_ThreadSync called!");
}
pub export fn Byond_GetStrId(...) u4c {
    @panic("stub function Byond_GetStrId called!");
}
pub export fn Byond_AddGetStrId(...) u4c {
    @panic("stub function Byond_AddGetStrId called!");
}
pub export fn Byond_ReadVar(...) bool {
    @panic("stub function Byond_ReadVar called!");
}
pub export fn Byond_ReadVarByStrId(...) bool {
    @panic("stub function Byond_ReadVarByStrId called!");
}
pub export fn Byond_WriteVar(...) bool {
    @panic("stub function Byond_WriteVar called!");
}
pub export fn Byond_WriteVarByStrId(...) bool {
    @panic("stub function Byond_WriteVarByStrId called!");
}
pub export fn Byond_CreateList(...) bool {
    @panic("stub function Byond_CreateList called!");
}
pub export fn Byond_ReadList(...) bool {
    @panic("stub function Byond_ReadList called!");
}
pub export fn Byond_WriteList(...) bool {
    @panic("stub function Byond_WriteList called!");
}
pub export fn Byond_ReadListAssoc(...) bool {
    @panic("stub function Byond_ReadListAssoc called!");
}
pub export fn Byond_ReadListIndex(...) bool {
    @panic("stub function Byond_ReadListIndex called!");
}
pub export fn Byond_WriteListIndex(...) bool {
    @panic("stub function Byond_WriteListIndex called!");
}
pub export fn Byond_ReadPointer(...) bool {
    @panic("stub function Byond_ReadPointer called!");
}
pub export fn Byond_WritePointer(...) bool {
    @panic("stub function Byond_WritePointer called!");
}
pub export fn Byond_CallProc(...) bool {
    @panic("stub function Byond_CallProc called!");
}
pub export fn Byond_CallProcByStrId(...) bool {
    @panic("stub function Byond_CallProcByStrId called!");
}
pub export fn Byond_CallGlobalProc(...) bool {
    @panic("stub function Byond_CallGlobalProc called!");
}
pub export fn Byond_CallGlobalProcByStrId(...) bool {
    @panic("stub function Byond_CallGlobalProcByStrId called!");
}
pub export fn Byond_ToString(...) bool {
    @panic("stub function Byond_ToString called!");
}
pub export fn Byond_Block(...) bool {
    @panic("stub function Byond_Block called!");
}
pub export fn Byond_Length(...) bool {
    @panic("stub function Byond_Length called!");
}
pub export fn Byond_LocateIn(...) bool {
    @panic("stub function Byond_LocateIn called!");
}
pub export fn Byond_LocateXYZ(...) bool {
    @panic("stub function Byond_LocateXYZ called!");
}
pub export fn Byond_New(...) bool {
    @panic("stub function Byond_New called!");
}
pub export fn Byond_NewArglist(...) bool {
    @panic("stub function Byond_NewArglist called!");
}
pub export fn Byond_Refcount(...) bool {
    @panic("stub function Byond_Refcount called!");
}
pub export fn Byond_XYZ(...) bool {
    @panic("stub function Byond_XYZ called!");
}
pub export fn Byond_PixLoc(...) bool {
    @panic("stub function Byond_PixLoc called!");
}
pub export fn Byond_BoundPixLoc(...) bool {
    @panic("stub function Byond_BoundPixLoc called!");
}
pub export fn ByondValue_IncRef(...) void {
    @panic("stub function ByondValue_IncRef called!");
}
pub export fn ByondValue_DecRef(...) void {
    @panic("stub function ByondValue_DecRef called!");
}
pub export fn ByondValue_DecTempRef(...) void {
    @panic("stub function ByondValue_DecTempRef called!");
}
pub export fn Byond_TestRef(...) bool {
    @panic("stub function Byond_TestRef called!");
}
pub export fn Byond_CRASH(...) noreturn {
    @panic("stub function Byond_CRASH called!");
}
