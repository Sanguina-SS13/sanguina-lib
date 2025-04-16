const std = @import("std");

const globals = @import("globals");
const core = globals.core;
const col = globals.collision;
const bit = globals.bitmath;

const ScanResult = struct {
    /// The bit-shifted collision fitting the new-found space.
    new_collision: u72,
    /// The floors we touched along the way. For passthrough handling.
    travel_path: u72,
    /// Are we suspended in mid-air and about to fall on our asses?
    zfall: bool,
};
fn scan_down_up(mover: col.CollisionDataExpanded, newloc_collision: u72) ?ScanResult {
    if (mover.collision_bitmask & newloc_collision == 0) {
        // doesnt overlap, see if we can lower the dood
        const starter_clz = @clz(mover.collision_bitmask);
        if (starter_clz == 0) {
            @branchHint(.unlikely);
            // invalid state but lets pretend it aint
            return ScanResult{
                .new_collision = mover.collision_bitmask,
                .travel_path = mover.collision_bitmask,
                .zfall = true, // get chasm'd quick tho
            };
        }

        const max_shift = @max(starter_clz, mover.step_size);
        var travel_path = mover.collision_bitmask;
        for (1..max_shift + 1) |shift| {
            const checked_mask = mover.collision_bitmask << shift;
            if (checked_mask & newloc_collision != 0) {
                @branchHint(.likely); // most common usecase: just walking along a straight floor
                return ScanResult{
                    .new_collision = mover.collision_bitmask << (shift - 1),
                    .travel_path = travel_path,
                    .zfall = false,
                };
            }

            travel_path |= (travel_path << 1);
        }

        // if we're still here, we're too low to shrimply step over; just return what we had with zfall as true.
        return ScanResult{
            .new_collision = mover.collision_bitmask,
            .travel_path = mover.collision_bitmask,
            .zfall = true,
        };
    } else {
        // there's something in the way, see what it takes to step over it
        var travel_path = mover.collision_bitmask;
        for (1..@ctz(mover.collision_bitmask) + 1) |shift| {
            const checked_mask = mover.collision_bitmask >> shift;
            travel_path |= (travel_path >> 1);

            if (checked_mask & newloc_collision == 0) {
                return ScanResult{
                    .new_collision = mover.collision_bitmask >> shift,
                    .travel_path = travel_path,
                    .zfall = false,
                };
            }
        }
        // couldnt find a place to put us
        return null;
    }
}

fn scan_from_top(mover: col.CollisionDataExpanded, newloc_collision: u72) ?ScanResult {
    const shifted = mover.collision_bitmask >> @ctz(mover.collision_bitmask);
    for (0..@clz(shifted)) |shift| {
        const checked_mask = shifted << shift;
        const floor_bits = bit.floor_bits(checked_mask);
        if (checked_mask & newloc_collision != 0)
            continue; // overlapping

        if (floor_bits & newloc_collision == 0)
            continue; // midair

        return ScanResult{
            .new_collision = checked_mask,
            .travel_path = checked_mask, // assume being god-yeeted or something idk.
            .zfall = false,
        };
    }
    return null;
}

fn scan_random(mover: col.CollisionDataExpanded, newloc_collision: u72, comptime ensure_grounded: bool) ?ScanResult {
    const rand = core.rand;

    const unshifted = mover.collision_bitmask << @clz(mover.collision_bitmask);
    const height_cap = @ctz(mover.collision_bitmask);

    // yada yada no unbounded
    for (0..256) |_| {
        // DRUNK DIALING WOO
        const drunk_dial = unshifted >> rand.uintLessThan(u7, height_cap + 1);
        if (drunk_dial & newloc_collision != 0) {
            continue;
        }

        const floor_bits = bit.floor_bits(drunk_dial);
        var zfall = false;
        if (@clz(drunk_dial) == 0 or floor_bits & newloc_collision == 0) {
            if (ensure_grounded) {
                continue;
            }
            zfall = true;
        }

        return ScanResult{
            .new_collision = drunk_dial,
            .travel_path = drunk_dial, // what, you expected a smooth transition?
            .zfall = zfall,
        };
    }
    return null;
}

const ScanMethod = enum {
    /// Used by entered_stacked(). Scans available floors from mover's current position, either upwards (up to height border) if blocked, or downwards (down to -step_size, past that ZFalls) if not.
    DownUp,
    // /// Alternates between checking the next upper and lower floor. Consequently, finds the nearest free space. Doesn't ZFall.
    // AlternateUpDown,
    /// Returns the first grounded free space. Doesn't ZFall.
    FirstFromTop,
    /// Returns a randomly picked available space. Doesn't ZFall.
    RandomGrounded,
    /// Returns a randomly picked available space, mid-air included.
    Random,
};
const FindFreeSpaceResult = struct {
    new_col_mask: u72,
    bumped: std.ArrayList(col.CollisionData),
    floor: ?col.CollisionData,
};
pub fn find_free_space(alloc: std.mem.Allocator, mover: col.CollisionDataExpanded, newloc_collision: []const col.CollisionData, comptime scan_method: ScanMethod) ?FindFreeSpaceResult {
    // As preface, because of the genereticity of this proc, NOCLIP is not considered.
    var total_collision_newloc: u72 = 0;
    for (newloc_collision) |collider| {
        if (!collider.flags.PASS_THROUGH)
            total_collision_newloc |= collider.collision_bitmask;
    }

    const maybe_scan_data = switch (scan_method) {
        .DownUp => scan_down_up(mover, total_collision_newloc),
        .FirstFromTop => scan_from_top(mover, total_collision_newloc),
        .Random => scan_random(mover, total_collision_newloc, false),
        .RandomGrounded => scan_random(mover, total_collision_newloc, true),
    };

    if (!maybe_scan_data) {
        return null;
    }
    const scan_data = maybe_scan_data.?;

    var passthroughs = std.ArrayList(col.CollisionData).init(alloc);
    for (newloc_collision) |collider| {
        if (!collider.flags.PASS_THROUGH)
            continue;

        if (collider.collision_bitmask & scan_data.travel_path)
            passthroughs.append(collider) catch unreachable;
    }

    const floor_bits = bit.floor_bits(mover.collision_bitmask);
    const floor = for (newloc_collision) |collider| {
        if (collider.flags.PASS_THROUGH)
            continue;

        if (collider.collision_bitmask & floor_bits)
            return collider;
    } else null;

    return FindFreeSpaceResult{
        .new_col_mask = scan_data.new_collision,
        .bumped = passthroughs,
        .floor = floor,
    };
}
