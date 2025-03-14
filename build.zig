const std = @import("std");

pub fn build(b: *std.Build) void {
    const code_model: std.builtin.CodeModel = .kernel;
    const linker_script_path: std.Build.LazyPath = b.path("linker.ld");
    var target_query: std.Target.Query = .{
        .cpu_arch = std.Target.Cpu.Arch.x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    };
    const Feature = std.Target.x86.Feature;

    target_query.cpu_features_add.addFeature(@intFromEnum(Feature.soft_float));
    target_query.cpu_features_sub.addFeature(@intFromEnum(Feature.mmx));
    target_query.cpu_features_sub.addFeature(@intFromEnum(Feature.sse));
    target_query.cpu_features_sub.addFeature(@intFromEnum(Feature.sse2));
    target_query.cpu_features_sub.addFeature(@intFromEnum(Feature.avx));
    target_query.cpu_features_sub.addFeature(@intFromEnum(Feature.avx2));
    const target = b.resolveTargetQuery(target_query);
    const optimize = b.standardOptimizeOption(.{});
    const limine = b.dependency("limine", .{});
    const kernel = b.addExecutable(.{
        .name = "kernel",
        .root_source_file = b.path("kernel/main.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = code_model,
    });
    kernel.addObjectFile(b.path("obj/idt.o"));
    kernel.addCSourceFile(.{
        .file = b.path("kernel/arch/x64/interrupts/idt.c"),
        .flags = &[_][]const u8{"-std=c99"},
    });
    kernel.addAssemblyFile(b.path("kernel/proc/sched.S"));
    kernel.addAssemblyFile(b.path("kernel/arch/x64/syscall/handle.S"));
    // kernel.addCSourceFile(b.path("kernel/arch/x64/interrupts/idt.h"));
    kernel.want_lto = false;
    //const root_source = b.path("kernel/main.zig");
    // Add Limine as a dependency.
    kernel.root_module.addImport("limine", limine.module("limine"));
    kernel.setLinkerScript(linker_script_path);

    b.installArtifact(kernel);
}
