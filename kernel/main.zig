const builtin = @import("builtin");
const limine = @import("limine");
const std = @import("std");
const tty = @import("drivers/tty/tty.zig");
const dbg = @import("drivers/dbg/dbg.zig");
const idt = @import("arch/x64/interrupts/handle.zig");
const pic = @import("drivers/pic/pic.zig");
const pageframe = @import("arch/x64/paging/pageframe_allocator.zig");

pub export var framebuffer_request: limine.FramebufferRequest = .{};
pub export var base_revision: limine.BaseRevision = .{ .revision = 2 };
inline fn done() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
const vmm = @import("arch/x64/paging/vmm.zig");
const pf = @import("arch/x64/paging/pageframe.zig");
const pci = @import("drivers/pci.zig");
const alloc = @import("arch/x64/paging/gp_allocator.zig");
export fn _start() callconv(.C) noreturn {
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
    //vmm.setup();
    pageframe.print_mem();
    pageframe.setup();
    dbg.printf("tty fb: {any}", .{tty.framebuffer});

    tty.printf("pageframe setup\n", .{});
    tty.printf("paging fully set up\n", .{});
    @import("arch/x64/gdt/gdt.zig").setup_gdt();
    idt.init();
    //tty.printf("IDT set up\n", .{});
    pic.PIC_remap(0x20, 0x20 + 8);
    //pic.IRQ_clear_mask(1);
    pic.clear_mask();
    asm volatile ("sti");

    tty.printf("Interrupts setup\n", .{});
    pci.init_devices();
    const allocator = alloc.init();
    dbg.printf("allocator initialised\n", .{});
    const a: []u8 = allocator.alloc(u8, 10) catch {
        @panic("allocator tests failed");
    };
    dbg.printf("alloc test: {x}\n", .{@intFromPtr(a.ptr)});
    tty.printf("paging setup\n", .{});
    tty.printf(" _______  _______  _______  _______  _______ \n", .{});
    tty.printf("(  ____ \\(  ___  )/ ___   )(  ___  )(  ____ \\\n", .{});
    tty.printf("| (    \\/| (   ) |\\/   )  || (   ) || (    \\/\n", .{});
    tty.printf("| (__    | |   | |    /   )| |   | || (_____ \n", .{});
    tty.printf("|  __)   | |   | |   /   / | |   | |(_____  )\n", .{});
    tty.printf("| (      | |   | |  /   /  | |   | |      ) |\n", .{});
    tty.printf("| )      | (___) | /   (_/\\| (___) |/\\____) |\n", .{});
    tty.printf("|/       (_______)(_______/(_______)\\_______)\n", .{});
    tty.printf("Boot finished!!!\n", .{});
    dbg.printf("FOZOS init done\n", .{});
    done();
}
pub fn panic(message: []const u8, trace: ?*std.builtin.StackTrace, addr: ?usize) noreturn {
    dbg.printf("FOZOS PANIC: {s}\n", .{message});
    tty.printf("FOZOS PANIC: {s}\n", .{message});
    if (addr) |a| {
        tty.printf("at 0x{x}\n", .{a});
    } else {
        tty.printf("no address\n", .{});
    }
    if (trace) |tr| {
        for (0..tr.index) |i| {
            tty.printf("i: {}. Instruction at: {x}\n", .{ i, tr.instruction_addresses[i] });
        }
    } else {
        tty.printf("no trace\n", .{});
    }
    done();
}
