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
pub export var address_request: limine.KernelAddressRequest = .{};
inline fn done() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
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

    idt.init();
    pic.PIC_remap(0x20, 0x20 + 8);
    //pic.IRQ_clear_mask(1);
    //pic.clear_mask();
    asm volatile ("sti");
    if (address_request.response) |response| {
        tty.printf("kernel loaded at 0x{x}(physical base) and 0x{x}(virtual base)\n", .{ response.physical_base, response.virtual_base });
    }
    tty.printf("Interrupts setup\n", .{});
    pageframe.print_mem();
    pageframe.setup();
    //    pf.remap_stack(8);
    pci.init_devices();
    //pf.dump_stack_values();
    const allocator = alloc.init();
    dbg.printf("allocator initialised\n", .{});
    const a: []u8 = allocator.alloc(u8, 10) catch {
        @panic("allocator tests failed");
    };
    dbg.printf("alloc test: {}\n", .{@intFromPtr(a.ptr)});
    tty.printf("paging setup\n", .{});
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
    done();
}
pub fn panic(message: []const u8, trace: ?*std.builtin.StackTrace, addr: ?usize) noreturn {
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
