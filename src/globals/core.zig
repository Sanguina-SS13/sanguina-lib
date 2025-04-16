const std = @import("std");

// ALLOC SHit

pub var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
/// Use for whatever needs to persist between calls.
pub const global_alloc = std.heap.page_allocator;
/// Use for temporary export-function-specific functions.
/// This is because many bapi functions call Byond_Crash()
/// which doesnt allow defered cleanup to occur.
pub const local_alloc = arena.allocator();
pub var rand: std.Random = undefined;
