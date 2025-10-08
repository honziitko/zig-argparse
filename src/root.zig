const std = @import("std");
const ArrayList = std.ArrayList;
const primitive = @import("primitive.zig");
const utils = @import("utils.zig");

pub const Flag = bool;

pub const Error = error{ UnknownOption, IntOverflow, IntSyntax, MissingValues, UnknownChoice };

pub fn writeError(comptime msg: []const u8, args: anytype) !void {
    const stderr = std.fs.File.stderr();
    var buf: [1024]u8 = undefined;
    const full_message = try std.fmt.bufPrint(&buf, "Error: " ++ msg ++ "\n", args);
    try stderr.writeAll(full_message);
}

fn checkType(T: type) void {
    const Base = utils.Enforce(T);
    const primitive_class = comptime primitive.classify(Base);
    if (primitive_class != null) return;
    if (comptime isCustomParsable(Base)) return;
    @compileError(std.fmt.comptimePrint("Argument type {s} must be one of: bool, integer, []const u8, or adhere to the interface", .{@typeName(T)}));
}

fn isCustomParsable(T: type) bool {
    switch (@typeInfo(T)) {
        .@"struct",
        .@"union",
        .@"enum",
        => {},
        else => return false,
    }
    if (!@hasDecl(T, "parse")) {
        return false;
    }
    return utils.checkFunctionConforms(@TypeOf(T.parse), &[_]type{ *ValueIterator, []const u8 }, T);
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
    var args_raw = try std.process.argsWithAllocator(ator);
    defer args_raw.deinit();
    var args = ArgsIterPeekable.init(&args_raw);

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
                checkType(T);
                if (std.mem.eql(u8, arg, longopt) or std.mem.startsWith(u8, arg, longopt ++ "=")) {
                    @field(out.options, field.name) = try parseOption(T, longopt, ValueIterator.init(arg, &args), out.arena.allocator());
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
                        checkType(T);
                        if (c == opt) {
                            @field(out.options, longopt) = try parseOption(T, "-" ++ field.name, ValueIterator.init(arg, &args), out.arena.allocator());
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

fn parseOption(T: type, name: []const u8, values_: ValueIterator, out_ator: std.mem.Allocator) !T {
    var values = values_;
    const Base = utils.Enforce(T);
    const primitive_class = comptime primitive.classify(Base);
    if (primitive_class) |prim_class| {
        switch (prim_class) {
            .flag => {
                return true;
            },
            .int => {
                const value = values.next() orelse {
                    try writeError("{s} expects 1 value", .{name});
                    return error.MissingValues;
                };
                return try primitive.parseInt(Base, value, name);
            },
            .uint => {
                const value = values.next() orelse {
                    try writeError("{s} expects 1 value", .{name});
                    return error.MissingValues;
                };
                return try primitive.parseUint(Base, value, name);
            },
            .string => {
                const value = values.next() orelse {
                    try writeError("{s} expects 1 value", .{name});
                    return error.MissingValues;
                };
                return try out_ator.dupe(u8, value);
            },
            .choice => {
                const value = values.next() orelse {
                    try writeError("{s} expects 1 value", .{name});
                    return error.MissingValues;
                };
                const out = std.meta.stringToEnum(Base, value);
                if (out) |o| {
                    return o;
                }
                var buf: [1024]u8 = undefined;
                var writer = std.Io.Writer.fixed(&buf);
                const fields = std.meta.fields(Base);
                inline for (fields, 0..) |field, i| {
                    switch (fields.len) {
                        1 => {}, // No comma can exist
                        2 => { // No oxford comma in binary sets
                            if (i == 1) try writer.writeAll(" or ");
                        },
                        else => {
                            if (i > 0) try writer.writeAll(", ");
                            if (i == fields.len - 1) try writer.writeAll("or ");
                        },
                    }
                    try writer.writeAll(field.name);
                }
                try writeError("{s} must be one of: {s}", .{ name, writer.buffered() });
                return error.UnknownChoice;
            },
        }
    } else {
        return try Base.parse(&values, name);
    }
}

///Iterate values of an argument. That is, the stream
///---key=X Y -Z
///would output X, Y, and halt.
pub const ValueIterator = struct {
    // Unparsed options of type --key=value
    equals_rest: []const u8,
    args: *ArgsIterPeekable,

    pub fn init(name: []const u8, args: *ArgsIterPeekable) ValueIterator {
        const equals_start = std.mem.indexOfScalar(u8, name, '=');
        var equals_rest: []const u8 = "";
        if (equals_start) |eq_start| {
            equals_rest = name[eq_start + 1 ..];
        }
        return .{
            .equals_rest = equals_rest,
            .args = args,
        };
    }

    fn isOption(arg: []const u8) bool {
        if (std.mem.startsWith(u8, arg, "--")) return true; //While -- is not an option, we should ignore it
        if (arg[0] == '-') return arg.len > 1;
        return false;
    }

    pub fn next(self: *ValueIterator) ?[]const u8 {
        if (self.equals_rest.len > 0) {
            const equals_pos = std.mem.indexOfScalar(u8, self.equals_rest, '=');
            if (equals_pos) |eq_pos| {
                const out = self.equals_rest[0..eq_pos];
                self.equals_rest = self.equals_rest[eq_pos + 1 ..];
                return out;
            } else {
                const out = self.equals_rest;
                self.equals_rest = "";
                return out;
            }
        }
        const next_arg = self.args.peek() orelse return null;
        if (isOption(next_arg)) return null;
        _ = self.args.next();
        return next_arg;
    }
};

const ArgsIterPeekable = struct {
    underlying_iter: *std.process.ArgIterator,
    cursor: ?[]const u8,

    pub fn init(args: *std.process.ArgIterator) ArgsIterPeekable {
        return .{
            .underlying_iter = args,
            .cursor = args.next(),
        };
    }

    pub fn peek(self: ArgsIterPeekable) ?[]const u8 {
        return self.cursor;
    }

    pub fn next(self: *ArgsIterPeekable) ?[]const u8 {
        const out = self.cursor;
        self.cursor = self.underlying_iter.next();
        return out;
    }
};
