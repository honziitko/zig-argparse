const std = @import("std");
const root = @import("root.zig");

pub const Class = enum { flag, int, uint, string };

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
        else => return null,
    }
}

pub fn parseInt(T: type, arg: []const u8, name: []const u8) !T {
    return std.fmt.parseInt(T, arg, 0) catch |e| switch (e) {
        error.Overflow => {
            try root.writeError("Integer {s} is too big", .{arg});
            return error.IntOverflow;
        },
        error.InvalidCharacter => {
            try root.writeError("{s} accepts an integer", .{name});
            return error.IntSyntax;
        },
    };
}

pub fn parseUint(T: type, arg: []const u8, name: []const u8) !T {
    return std.fmt.parseInt(T, arg, 0) catch |e| switch (e) {
        error.Overflow => {
            if (arg.len > 0 and arg[0] == '-') {
                try root.writeError("{s} must be positive", .{name});
            } else {
                try root.writeError("Integer {s} is too big", .{arg});
            }
            return error.IntOverflow;
        },
        error.InvalidCharacter => {
            try root.writeError("{s} accepts an unsigned integer", .{name});
            return error.IntSyntax;
        },
    };
}
