const std = @import("std");
const root = @import("root.zig");
const utils = @import("utils.zig");

pub const Class = enum { flag, int, uint, string, choice };

pub fn classify(T: type) ?Class {
    if (T == []const u8) {
        return .string;
    }
    switch (@typeInfo(T)) {
        .int => |int| switch (int.signedness) {
            .signed => return .int,
            .unsigned => return .uint,
        },
        .bool => return .flag,
        .@"enum" => return .choice,
        else => return null,
    }
}

pub fn parseInt(T: type, arg: []const u8, name: []const u8, error_writer: *std.Io.Writer) !T {
    return std.fmt.parseInt(T, arg, 0) catch |e| switch (e) {
        error.Overflow => {
            try root.writeError(error_writer, "Integer {s} is too big", .{arg});
            return error.IntOverflow;
        },
        error.InvalidCharacter => {
            try root.writeError(error_writer, "{s} accepts an integer", .{name});
            return error.IntSyntax;
        },
    };
}

pub fn parseUint(T: type, arg: []const u8, name: []const u8, error_writer: *std.Io.Writer) !T {
    return std.fmt.parseInt(T, arg, 0) catch |e| switch (e) {
        error.Overflow => {
            if (arg.len > 0 and arg[0] == '-') {
                try root.writeError(error_writer, "{s} must be positive", .{name});
            } else {
                try root.writeError(error_writer, "Integer {s} is too big", .{arg});
            }
            return error.IntOverflow;
        },
        error.InvalidCharacter => {
            try root.writeError(error_writer, "{s} accepts an unsigned integer", .{name});
            return error.IntSyntax;
        },
    };
}

const testing = std.testing;
test "classification" {
    const complex = [_]type{ type, void, noreturn, *i32, [2]u8, struct {}, comptime_float, comptime_int, @TypeOf(undefined), ?i32, error{}!i32, error{}, union {}, fn () void, @Vector(2, i32), @TypeOf(.enum_literal) };
    inline for (complex) |T| {
        try testing.expectEqual(null, classify(T));
    }
    try testing.expectEqual(.flag, classify(bool));
    try testing.expectEqual(.int, classify(i32));
    try testing.expectEqual(.uint, classify(u32));
    try testing.expectEqual(.string, classify([]const u8));
    try testing.expectEqual(.choice, classify(enum {}));
}
