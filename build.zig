const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const argparse = b.addModule("argparse", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    example.root_module.addImport("argparse", argparse);
    b.installArtifact(example);

    const run_example = b.addRunArtifact(example);

    if (b.args) |args| {
        run_example.addArgs(args);
    }

    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_example.step);
}
