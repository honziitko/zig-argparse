const std = @import("std");
const argparse = @import("argparse");

const Args = struct {
    foo: ?[]const u8 = null,
    bar: ?u32 = null,

    pub const shorthands = .{
        .f = "foo",
        .b = "bar",
    };
};

pub fn main() !void {
    const ator = std.heap.page_allocator;
    const args = argparse.parse(Args, ator) catch |e| switch (e) {
        error.UnknownOption,
        error.IntOverflow,
        error.IntSyntax,
        error.MissingValues,
        => return std.process.exit(1),
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
