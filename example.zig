const std = @import("std");
const argparse = @import("argparse");

const Args = struct {
    foo: argparse.Flag = false,
    bar: argparse.Flag = false,
    // baz: i32 = 69,

    pub const shorthands = .{
        .f = "foo",
        .b = "bar",
    };
};

pub fn main() !void {
    const ator = std.heap.page_allocator;
    const args = argparse.parse(Args, ator) catch |e| switch (e) {
        error.UnknownOption => return std.process.exit(1),
        else => return e,
    };
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
