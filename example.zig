const std = @import("std");
const argparse = @import("argparse");

const Unary = enum { literally }; // 1984
const Binary = enum { yes, no };
const Ternary = enum { I, II, III };
const IDontSpeakLatin = enum { A, B, C, D };

const Args = struct {
    one: Unary = .literally,
    two: Binary = .no,
    three: Ternary = .I,
    four: IDontSpeakLatin = .A,

    pub const shorthands = .{};
};

pub fn main() !void {
    const ator = std.heap.page_allocator;
    const args = argparse.parse(Args, ator) catch |e| switch (e) {
        error.UnknownOption,
        error.MissingValues,
        error.UnknownChoice,
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
