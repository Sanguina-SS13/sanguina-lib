const std = @import("std");
const def = @import("../defines.zig");
const compgen = @import("_compgen_out.zig");

pub const AREA = _comptime_data.AREA; //_compile_atom_enum(comptime_data.areas, def._AREA);
pub const TURF = _comptime_data.TURF; //_compile_atom_enum(comptime_data.turfs, def._TURF);
pub const MOVABLE = _comptime_data.MOVABLE; //_compile_atom_enum(comptime_data.movables, def._MOVABLE);
pub const structure_map = _comptime_data.structure_map; // = _compile_template_data(comptime_data.template_data);

const _comptime_data: COMPTIME_DATA_TYPE = _compile_comptime_data();

const COMPTIME_DATA_TYPE = struct { AREA: type, TURF: type, MOVABLE: type, structure_map: std.StaticStringMap(def.template_data) };

const DMM_DATA = struct {
    map_data: def.map_data,
    areas: [][]const u8,
    turfs: [][]const u8,
    movables: [][]const u8,
};

fn _compile_comptime_data() COMPTIME_DATA_TYPE {
    std.debug.assert(@inComptime());

    var ret: COMPTIME_DATA_TYPE = undefined;

    //wonky layout so we can yeet them into staticstringmap
    var areas: []struct { []const u8 } = &.{};
    var turfs: []struct { []const u8 } = &.{};
    var movables: []struct { []const u8 } = &.{};
    var structure_list: []struct { map_data: def.map_data, map_config: def.map_config } = &.{};

    for (compgen.FILES) |value| {
        const dmm = _parse_dmm_file(value.dmm, value.filename);
        var json = _parse_json_file(value.json, value.filename);
        json.len_x = dmm.map_data.width;
        json.len_y = dmm.map_data.height;
        json.len_z = dmm.map_data.z_levels;

        for (dmm.areas) |path|
            areas = areas ++ .{path};
        for (dmm.turfs) |path|
            turfs = turfs ++ .{path};
        for (dmm.movables) |path|
            movables = movables ++ .{path};

        structure_list = structure_list ++ .{ .map_data = dmm.map_data, .map_config = json };
    }

    const less_than = struct {
        fn lessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
            return std.mem.order(u8, lhs[6..], rhs[6..]) == .lt;
        }
    }.lessThan;

    const remove_dupes = struct {
        fn remove_dupes(arr: []const u8) []const u8 {
            var j: usize = 0;
            for (arr[1..]) |item| {
                if (arr[j] != item) {
                    j += 1;
                    arr[j] = item;
                }
            }
            return arr[0 .. j + 1];
        }
    }.remove_dupes;

    const area_set = std.StaticStringMap(void).initComptime(areas);
    const turf_set = std.StaticStringMap(void).initComptime(turfs);
    const movable_set = std.StaticStringMap(void).initComptime(movables);

    var area_fields: [area_set.len_indexes + @typeInfo(def._AREA).@"struct".fields.len]std.builtin.Type.EnumField = undefined;
    var turf_fields: [turfs.len + @typeInfo(def._TURF).@"struct".fields.len]std.builtin.Type.EnumField = undefined;
    var movable_fields: [areas.len + @typeInfo(def._MOVABLE).@"struct".fields.len]std.builtin.Type.EnumField = undefined;
    for (@typeInfo(def._AREA).@"enum", 0..) |decl, i| {
        area_fields[i] = decl;
    }

    for (atoms) |path| switch (path[1]) {
        'a' => area_list = area_list ++ path,
        't' => turf_list = turf_list ++ path,
        'o', 'm' => movable_list = movable_list ++ path,
        _ => {
            @branchHint(.cold);
            @compileLog(std.fmt.comptimePrint("found {s} in paths!", .{}));
        },
    };

    for (@typeInfo(def._AREA).@"struct".decls, @typeInfo(def._AREA).@"struct".fields) |decl, type| {
        //area_fields[i]
    }
    for (areas, 0..) |path, i| {
        //fields[i] = .{.name = std.fmt.comptimePrint("_GEN_{}", args: anytype)}
    }
    //
    //    for (atom_list, 0..) |path, i| {
    //        fields[i] = .{ .name = std.fmt.comptimePrint("_GEN_{d}", .{i}), .value = path };
    //    }
    //
    //    return @Type(.{ .Enum = .{
    //        .tag_type = u32,
    //        .fields = &fields,
    //        .decls = &.{},
    //        .is_exhaustive = true,
    //    } });
    //     std.StaticStringMap(comptime V: type)

    for (structure_list) |value| {}

    return ret;
}

fn _compile_atom_enum(atom_list: [][]const u8, presets: type) type {
    var fields: [atom_list.len + presets]std.builtin.Type.EnumField = undefined;

    for (atom_list, 0..) |path, i| {
        fields[i] = .{ .name = std.fmt.comptimePrint("_GEN_{d}", .{i}), .value = path };
    }

    return @Type(.{ .Enum = .{
        .tag_type = u32,
        .fields = &fields,
        .decls = &.{},
        .is_exhaustive = true,
    } });
}

fn _parse_json_file(json: []const u8, filename: []const u8) def.map_config {
    std.debug.assert(@inComptime());

    var buffer: [32]u8 = undefined;
    const comptime_alloc = std.heap.FixedBufferAllocator.init(&buffer);
    const parsed = std.json.parseFromSliceLeaky(def.map_config, comptime_alloc, json, .{ .duplicate_field_behavior = .@"error" }) catch |err| {
        @panic(err);
    };

    if (parsed.id.len == 0) {
        @panic(std.fmt.comptimePrint("ERROR: Missing .json entry for {s} - [id]\n", .{filename}));
    }
    if (parsed.always_place) {
        if (parsed.placement_weight != 0) {
            std.debug.print("WARNING: Redundant .json [placement_weight] entry set for {s} - [always_place] is set to true!", .{filename});
        }
        if (parsed.cost != 0) {
            std.debug.print("WARNING: Redundant .json [cost] entry set for {s} - [always_place] is set to true!", .{filename});
        }
    }
    return parsed;
}

fn _parse_dmm_file(comptime dmm: []const u8, comptime filename: []const u8) DMM_DATA {
    std.debug.assert(@inComptime());

    const STAGE = enum {
        // token parsing
        OUTER_TOKENS,
        IN_TOKEN_DEF,
        AFTER_TOKEN,
        IN_TYPES,
        IN_VARS,
        // map parsing
        OUTER_MAP,
        IN_COORDS,
        AFTER_COORDS,
        IN_TOKEN_STRING,
    };

    const TILE_DEF = struct {
        token: [3]u8,
        areas: [][]const u8,
        turfs: [][]const u8,
        movables: [][]const u8,
    };

    var area_list: [][]const u8 = &.{};
    var turf_list: [][]const u8 = &.{};
    var movable_list: [][]const u8 = &.{};

    var tile_def_list: []TILE_DEF = &.{};
    var current_tile_def: TILE_DEF = .{};

    var map_data: []def.tile_data = &.{};
    var max_x: u10 = 0;
    var max_y: u10 = 0;
    var max_z: u10 = 0; //for completeness sake, even tho having 1024 z levels is retarded

    //case-sensitive a-z. even a bulky map like multiz icebox didnt get to capital letters for its first signifier. you will NEVER need anything above this.
    var current_token: [3]u8 = @splat('_');
    var token_length: u2 = 0;
    var token_iter: u2 = 0;

    var current_typepath: []const u8 = "";

    var current_coord_set: [3]u10 = undefined;
    var coord_iter: u2 = 0;
    var coord_str_holder = "";

    var stage: STAGE = STAGE.OUTER_TOKENS;
    var skip_whitespace = true;
    var skip_next_token = false;

    // the format we're working around:
    // "token" = (/paths, /more/paths, /sometimes/paths{with = vars; even_more = list(vars)})
    // "other" = (/paths, /more/paths, /sometimes/paths{with = vars; even_more = list(vars)})
    // "idkkk" = (/paths, /more/paths, /sometimes/paths{with = vars; even_more = list(vars)})
    //
    // (1,1,1) = "tokenotheridkkkotherothertokenidkkk"
    // (2,1,1) = "..."
    //
    // no whitespace sanity is guaranteed
    var tile_data_map: std.StaticStringMapWithEql(def.tile_data, std.static_string_map.defaultEql) = undefined;
    for (dmm) |char| {
        // backslash
        if (char == '\\') {
            @branchHint(.unlikely);
            skip_next_token = true;
            continue;
        }
        if (skip_next_token) {
            @branchHint(.unlikely);
            skip_next_token = false;
            continue;
        }
        // whitespace
        if (skip_whitespace and std.ascii.isWhitespace(char)) {
            continue;
        }

        switch (stage) {
            //token def
            .OUTER_TOKENS => switch (char) {
                '"' => stage = .IN_TOKEN_DEF,
                '(' => {
                    tile_data_map = std.StaticStringMap(def.tile_data).initComptime(tile_def_list);
                    stage = .OUTER_MAP;
                },
                _ => @compileError(std.fmt.comptimePrint("{s} - found identifier: {c}, expected: [(\"]", .{ filename, char })),
            },
            .IN_TOKEN_DEF => switch (char) {
                'a'...'z', "A"..."Z" => {
                    current_token[token_iter] = char;
                    token_iter += 1;
                },
                '"' => {
                    if (token_length == 0) {
                        token_length = token_iter + 1;
                    } else if (token_length != token_iter + 1) {
                        @branchHint(.cold);
                        @compileError(std.fmt.comptimePrint("{s} - token length mismatch", .{filename}));
                    }
                    stage = .AFTER_TOKEN;
                },
                _ => {
                    @branchHint(.cold);
                    @compileError(std.fmt.comptimePrint("{s} - found identifier: {c}, expected: [a-zA-Z\"]", .{ filename, char }));
                },
            },
            .AFTER_TOKEN => switch (char) {
                '=' => continue,
                '(' => stage = .IN_TYPES,
                _ => {
                    @branchHint(.cold);
                    @compileError(std.fmt.comptimePrint("{s} - found identifier: {c}, expected: [=(]", .{ filename, char }));
                },
            },
            .IN_TYPES => switch (char) {
                'a'...'z', 'A'...'Z', '0'...'9', '_', '/' => current_typepath = current_typepath ++ char,
                ',', ')' => {
                    switch (current_typepath[1]) {
                        'a' => area_list = area_list ++ current_typepath,
                        't' => turf_list = turf_list ++ current_typepath,
                        'o', 'm' => movable_list = movable_list ++ current_typepath,
                        _ => {
                            @branchHint(.cold);
                            @compileLog(std.fmt.comptimePrint("{s} - found {s} in token {s}", .{ filename, current_typepath, current_token }));
                        },
                    }
                    current_tile_def.data = current_tile_def.data ++ current_typepath;
                    current_typepath = "";

                    if (char == ')') {
                        tile_def_list = tile_def_list ++ current_tile_def;
                        current_tile_def.data = &.{};
                        stage = .OUTER_TOKENS;
                    }
                },
                '{' => stage = .IN_VARS,
                _ => @compileError(std.fmt.comptimePrint("{s} - found identifier: {c}, expected: [a-zA-Z0-9_/,]", .{ filename, char })),
            },
            .IN_VARS => switch (char) {
                _ => @compileError("yeah we didnt implement this, and byond doesnt support runtime pops either. fix your map so it doesnt have custom var overrides i guess?"),
            },
            // map def
            .OUTER_MAP => {
                if (char != '(') {
                    @branchHint(.cold);
                    @compileError("found identifier: {c}, expected: [(]");
                }
                stage = .IN_COORDS;
            },
            .IN_COORDS => switch (char) {
                '0'...'9' => coord_str_holder = coord_str_holder ++ char,
                ',' => {
                    current_coord_set[coord_iter] = std.fmt.parseInt(u10, coord_str_holder, 10) catch |err| switch (err) {
                        error.OverFlow => @compileError(std.fmt.comptimePrint("{s} - why the fuck is your map larger than 1024 tiles in height", .{filename})),
                        error.InvalidCharacter => @compileError(std.fmt.comptimePrint("invalid character in coords string: coord {d} is {s}", .{ coord_iter, coord_str_holder })),
                    };
                    coord_iter += 1;
                    if (coord_iter == 3)
                        @compileError(std.fmt.comptimePrint("{s} - coord_iter somehow reached 3!", .{filename})); // this should never happen as we always expect 3 coords - x y z
                },
                ')' => {
                    if (coord_iter != 2) //see above
                        @compileError(std.fmt.comptimePrint("{s} - coord_iter expected to be 2 but is {d}!", .{ filename, coord_iter }));

                    max_x = @max(max_x, current_coord_set[0]);
                    max_y = @max(max_y, current_coord_set[1]);
                    max_z = @max(max_z, current_coord_set[2]);

                    coord_iter = 0;
                    stage = .AFTER_COORDS;
                },
                _ => @compileError(std.fmt.comptimePrint("{s} - found identifier: {c}, expected: [0-9,(]", .{ filename, char })),
            },
            .AFTER_COORDS => switch (char) {
                '=' => continue,
                '"' => stage = .IN_TOKEN_STRING,
                _ => {
                    @branchHint(.cold);
                    @compileError(std.fmt.comptimePrint("{s} - found identifier: {c}, expected: [=(]", .{ filename, char }));
                },
            },
            .IN_TOKEN_STRING => switch (char) {
                'a'...'z', 'A'...'Z' => {
                    current_token[token_iter] = char;
                    token_iter += 1;

                    if (token_iter == token_length) {
                        map_data = map_data ++ tile_data_map.get(current_token[0..token_length]) catch @compileError(std.fmt.comptimePrint("{s} - invalid token in map parsing", .{filename}));
                        current_coord_set[1] += 1;
                        token_iter = 0;
                    }
                },
                '"' => {
                    if (token_iter != 0) {
                        @branchHint(.cold);
                        @compileError(std.fmt.comptimePrint("{s} - token string length mismatch", .{filename}));
                    }

                    max_y = @max(max_y, current_coord_set[1]);
                    stage = .OUTER_MAP;
                },
                _ => {
                    @branchHint(.cold);
                    @compileError(std.fmt.comptimePrint("{s} - found identifier: {c}, expected [a-zA-Z\"]", .{ filename, char }));
                },
            },
        }
    }

    return .{
        .tile_data = def.map_data{
            .height = max_y,
            .width = max_x,
            .z_levels = max_z,
            .tile_data = map_data,
        },
        .areas = area_list,
        .turfs = turf_list,
        .movables = movable_list,
    };
}
