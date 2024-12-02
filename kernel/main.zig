const builtin = @import("builtin");
const limine = @import("limine");
const std = @import("std");
const tty = @import("drivers/tty/tty.zig");
const dbg = @import("drivers/dbg/dbg.zig");
const idt = @import("arch/x64/interrupts/idt.zig");
const pic = @import("drivers/pic/pic.zig");
// The Limine requests can be placed anywhere, but it is important that
// the compiler does not optimise them away, so, usually, they should
// be made volatile or equivalent. In Zig, `export var` is what we use.
pub export var framebuffer_request: limine.FramebufferRequest = .{};

// Set the base revision to 2, this is recommended as this is the latest
// base revision described by the Limine boot protocol specification.
// See specification for further info.
pub export var base_revision: limine.BaseRevision = .{ .revision = 2 };
pub export var address_request: limine.KernelAddressRequest = .{};
inline fn done() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

// The following will be our kernel's entry point.
export fn _start() callconv(.C) noreturn {
    // Ensure the bootloader actually understands our base revision (see spec).
    if (!base_revision.is_supported()) {
        done();
    }

    // Ensure we got a framebuffer.
    if (framebuffer_request.response) |framebuffer_response| {
        dbg.printf("init framebuffer\n", .{});
        tty.initialise_tty(framebuffer_response);
        dbg.printf("init framebuffer done\n", .{});
    } else {
        dbg.printf("FRAMEBUFFER FAIL\n", .{});
    }

    idt.initidt();

    pic.PIC_remap(0x20, 0x20 + 8);
    pic.clear_mask();
    asm volatile ("sti");
    if (address_request.response) |response| {
        tty.printf("kernel loaded at 0x{x}(physical base) and 0x{x}(virtual base)\n", .{ response.physical_base, response.virtual_base });
    }
    tty.printf(" _______  _______  _______  _______  _______ \n", .{});
    tty.printf("(  ____ \\(  ___  )/ ___   )(  ___  )(  ____ \\\n", .{});
    tty.printf("| (    \\/| (   ) |\\/   )  || (   ) || (    \\/\n", .{});
    tty.printf("| (__    | |   | |    /   )| |   | || (_____ \n", .{});
    tty.printf("|  __)   | |   | |   /   / | |   | |(_____  )\n", .{});
    tty.printf("| (      | |   | |  /   /  | |   | |      ) |\n", .{});
    tty.printf("| )      | (___) | /   (_/\\| (___) |/\\____) |\n", .{});
    tty.printf("|/       (_______)(_______/(_______)\\_______)\n", .{});
    tty.printf("Hello from FOZOS!!!\n", .{});
    dbg.printf("FOZOS init done\n", .{});
    //done();
    while (true) {
        done();
    }
}
