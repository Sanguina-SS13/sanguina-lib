const std = @import("std");

//precompile read only shit
pub const _AREA = enum([]const u8) {
    WASTES = "/area/wilderness/wastes",
    MAGMA_SWAMP = "/area/wilderness/magma_swamp",
    FUNGUS_FOREST = "/area/wilderness/fungus_forest",
    LEGION = "/area/wilderness/legion",
};

const _TURF = enum([]const u8) {
    BASALT = "/turf/open/basalt",
    ROCK = "/turf/closed/mineral",
};

const _MOVABLE = struct {};

//map stuff
pub const SIZE_X = 255; //size of one z level
pub const SIZE_Y = 255;
pub const SIZE_Z = 9;

//compgen map template data, stored as "id" = template_data{}
pub const map_config = struct {
    id: []const u8 = "",
    always_place: bool = false,
    placement_weight: u8 = 0,
    cost: u8 = 0,
    allow_duplicates: bool = true,
    //ruin_type:

    len_x: u10 = undefined,
    len_y: u10 = undefined,
    len_z: u10 = undefined,
};

pub const template_data = struct {
    map_config: map_config,
    map_data: []tile_data,
};

pub const map_data = struct {
    width: u10,
    height: u10,
    z_levels: u10,
    tile_data: []tile_data,
};

pub const tile_data = struct {
    area: []const u8,
    turf: []const u8,
    movables: [][]const u8,
};

//const structure_lookup = std.StaticStringMap(template_data).initComptime(
//    .{id, template_data{
//        .map_config = .{},
//        .map_data = [],
//    }}
//);
