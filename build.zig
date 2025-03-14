const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libgc = b.dependency("bdwgc", .{ .target = target, .optimize = optimize });
    // TODO(mitchellh): support more complex features that are usually on
    // with libgc like threading, parallelization, etc.
    const cflags = [_][]const u8{};
    const libgc_srcs = [_][]const u8{
        "alloc.c",    "reclaim.c", "allchblk.c", "misc.c",     "mach_dep.c", "os_dep.c",
        "mark_rts.c", "headers.c", "mark.c",     "obj_map.c",  "blacklst.c", "finalize.c",
        "new_hblk.c", "dbg_mlc.c", "malloc.c",   "dyn_load.c", "typd_mlc.c", "ptr_chck.c",
        "mallocx.c",
    };
    // libgc
    const gc = b.addStaticLibrary(.{
        .name = "gc",
        .target = target,
        .optimize = optimize,
    });
    {
        gc.defineCMacro("GC_DEBUG", "1");
        gc.linkLibC();
        gc.addIncludePath(libgc.path("include"));
        gc.addCSourceFiles(.{ .root = libgc.path(""), .files = &libgc_srcs, .flags = &cflags });
        // gc.installHeadersDirectory(libgc.path("include"), "", .{});
        const gc_step = b.step("libgc", "build libgc");
        gc_step.dependOn(&gc.step);
        b.installArtifact(gc);
    }

    // lib for zig
    const lib = b.addStaticLibrary(.{
        .name = "zgc",
        .root_source_file = b.path("src/gc.zig"),
        .target = target,
        .optimize = optimize,
    });
    {
        var main_tests = b.addTest(.{
            .root_source_file = b.path("src/gc.zig"),
            .target = target,
            .optimize = optimize,
        });
        main_tests.linkLibC();
        main_tests.addIncludePath(libgc.path("include"));
        main_tests.linkLibrary(gc);

        const test_step = b.step("test", "Run library tests");
        test_step.dependOn(&main_tests.step);

        b.default_step.dependOn(&lib.step);
        b.installArtifact(lib);
    }

    const module = b.addModule("gc", .{
        .root_source_file = b.path("src/gc.zig"),
    });
    module.linkLibrary(gc);

    // example app
    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("example/basic.zig"),
        .target = target,
        .optimize = optimize,
    });
    {
        b.installArtifact(exe);
        exe.linkLibrary(gc);
        exe.root_module.addImport("gc", module);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run_example", "run example");
        run_step.dependOn(&run_cmd.step);
    }
}
