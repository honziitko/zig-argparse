const std = @import("std");
const argparse = @import("argparse");

const T = struct {
    value: usize = 0,

    pub fn parse(args: *argparse.ValueIterator, name: []const u8, error_writer: *std.Io.Writer) !T {
        const arg = args.next() orelse {
            try argparse.writeError(error_writer, "{s} expects 1 value", .{name});
            return error.MissingValues;
        };
        std.debug.print("Arg: \"{s}\"\n", .{arg});
        return T{
            .value = arg.len,
        };
    }
};

const U = struct {};

const V = struct {
    pub fn parse(_: i32) V {
        return undefined;
    }
};

const Args = struct {
    foo: ?T = null,
    bar: ?u32 = null,

    pub const shorthands = .{};
};

pub fn main() !void {
    const ator = std.heap.page_allocator;
    const args = argparse.parse(Args, ator) catch |e| switch (e) {
        error.UnknownOption,
        error.MissingValues,
        => std.process.exit(1),
        else => return e,
    };
    defer args.deinit();
    std.debug.print("Self name: {?s}\n", .{args.self_name});
    std.debug.print("{}\n", .{args.options});
    std.debug.print("Positionals: ", .{});
    for (args.positionals.items, 0..) |pos, i| {
        if (i > 0) {
            std.debug.print(", ", .{});
        }
        std.debug.print("{s}", .{pos});
    }
    std.debug.print("\n", .{});
}
