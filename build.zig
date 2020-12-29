const std = @import("std");
const Builder = std.build.Builder;


pub fn build(b: *Builder) !void {

    const target = b.standardTargetOptions(.{
    .default_target = try std.zig.CrossTarget.parse(.{
        .arch_os_abi = if (std.builtin.os.tag == .windows)
            "native-native-gnu"
        else
            "native-linux-musl",
    }),
    });

    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("sfml", "src/main.zig");
    exe.linkLibC();
    exe.addPackagePath("sfml", "sfml-wrapper/src/sfml/sfml.zig");
    exe.addLibPath("csfml/lib/gcc/");
    exe.linkSystemLibrary("csfml-graphics");
    exe.linkSystemLibrary("csfml-system");
    exe.linkSystemLibrary("csfml-window");
    exe.linkSystemLibrary("csfml-audio");
    exe.addIncludeDir("csfml/include/");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_step = b.step("run", "Run the program");
    run_step.dependOn(&exe.run().step);
}
