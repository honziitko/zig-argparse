const std = @import("std");
const ArrayList = std.ArrayList;

pub const Flag = bool;

pub const Error = error{UnknownOption};

pub fn writeError(comptime msg: []const u8, args: anytype) !void {
    const stderr = std.fs.File.stderr();
    var buf: [1024]u8 = undefined;
    const full_message = try std.fmt.bufPrint(&buf, "Error: " ++ msg ++ "\n", args);
    try stderr.writeAll(full_message);
}

fn Parsed(Schema: type) type {
    return struct {
        const Self = @This();
        options: Schema = .{},
        positionals: ArrayList([]const u8) = .empty,
        arena: std.heap.ArenaAllocator,
        self_name: ?[]const u8 = null,

        pub fn init(ator: std.mem.Allocator) Self {
            return .{
                .arena = .init(ator),
            };
        }

        pub fn deinit(self: Self) void {
            self.arena.deinit();
        }

        fn allocString(self: *Self, str: []const u8) ![]const u8 {
            return try self.arena.allocator().dupe(u8, str);
        }
    };
}

pub fn parse(Schema: type, ator: std.mem.Allocator) !Parsed(Schema) {
    var args = try std.process.argsWithAllocator(ator);
    defer args.deinit();

    var out = Parsed(Schema).init(ator);

    if (args.next()) |self_name| {
        out.self_name = try out.allocString(self_name);
    }

    outer_loop: while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--")) {
            break;
        }
        if (std.mem.startsWith(u8, arg, "--")) {
            inline for (std.meta.fields(Schema)) |field| {
                const longopt = "--" ++ field.name;
                const T = @FieldType(Schema, field.name);
                comptime std.debug.assert(T == Flag); //TODO: add other types
                if (std.mem.eql(u8, arg, longopt)) {
                    @field(out.options, field.name) = true;
                    continue :outer_loop;
                }
            }
            // Starts with -- but is not a long option
            try writeError("Unknown option: {s}", .{arg});
            return error.UnknownOption;
        }
        if (arg[0] == '-') {
            if (arg.len == 1) {
                // `-` is a positional argument, usually stdin
                try out.positionals.append(ator, arg);
                continue;
            }
            if (@hasDecl(Schema, "shorthands")) {
                const shorts = Schema.shorthands;
                char_loop: for (arg[1..]) |c| {
                    inline for (std.meta.fields(@TypeOf(shorts))) |field| {
                        comptime std.debug.assert(field.name.len == 1); //A short option always has length 1
                        const opt = field.name[0];
                        const longopt = @field(shorts, field.name);
                        const T = @FieldType(Schema, longopt);
                        comptime std.debug.assert(T == Flag); //TODO: add other types
                        if (c == opt) {
                            @field(out.options, longopt) = true;
                            continue :char_loop;
                        }
                    }
                    try writeError("Unknown option: -{c}", .{c});
                    return error.UnknownOption;
                }
            } else {
                try writeError("Unknown option: -{c}", .{arg[1]});
                return error.UnknownOption;
            }
            continue;
        }
        // Otherwise, it's positional
        try out.positionals.append(ator, arg);
    }
    // Collect args after --
    while (args.next()) |arg| {
        try out.positionals.append(ator, arg);
    }
    return out;
}
