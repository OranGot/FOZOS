const dbg = @import("../../../drivers/dbg/dbg.zig");
const tty = @import("../../../drivers/tty/tty.zig");
const pic = @import("../../../drivers/pic/pic.zig");
pub const int_regs = extern struct {
    r15: u64 = @import("std").mem.zeroes(u64),
    r14: u64 = @import("std").mem.zeroes(u64),
    r13: u64 = @import("std").mem.zeroes(u64),
    r12: u64 = @import("std").mem.zeroes(u64),
    r11: u64 = @import("std").mem.zeroes(u64),
    r10: u64 = @import("std").mem.zeroes(u64),
    r9: u64 = @import("std").mem.zeroes(u64),
    r8: u64 = @import("std").mem.zeroes(u64),
    rbp: u64 = @import("std").mem.zeroes(u64),
    rdi: u64 = @import("std").mem.zeroes(u64),
    rsi: u64 = @import("std").mem.zeroes(u64),
    rdx: u64 = @import("std").mem.zeroes(u64),
    rcx: u64 = @import("std").mem.zeroes(u64),
    rbx: u64 = @import("std").mem.zeroes(u64),
    rax: u64 = @import("std").mem.zeroes(u64),
    int_no: u64 = @import("std").mem.zeroes(u64),
    error_code: u64 = @import("std").mem.zeroes(u64),
    rip: u64 = @import("std").mem.zeroes(u64),
    cs: u64 = @import("std").mem.zeroes(u64),
    rflags: u64 = @import("std").mem.zeroes(u64),
    rsp: u64 = @import("std").mem.zeroes(u64),
    ss: u64 = @import("std").mem.zeroes(u64),
};
pub const idt_entry_t = extern struct {
    isr_low: u16 align(1) = @import("std").mem.zeroes(u16),
    kernel_cs: u16 align(1) = @import("std").mem.zeroes(u16),
    ist: u8 align(1) = @import("std").mem.zeroes(u8),
    attributes: u8 align(1) = @import("std").mem.zeroes(u8),
    isr_mid: u16 align(1) = @import("std").mem.zeroes(u16),
    isr_high: u32 align(1) = @import("std").mem.zeroes(u32),
    reserved: u32 align(1) = @import("std").mem.zeroes(u32),
};
pub const idtr_t = extern struct {
    limit: u16 align(1) = @import("std").mem.zeroes(u16),
    base: u64 align(1) = @import("std").mem.zeroes(u64),
};
var int_handle_t: [224]?*const fn (*int_regs) void = undefined;
///Binds a specific vector
pub fn bind_vector(te: ?*const fn (*int_regs) void, v: u16) ?void {
    if (v > 255) return null;
    dbg.printf("checking index: {any}\n", .{int_handle_t[v - 32]});
    if (int_handle_t[v - 32] != null) return null;
    dbg.printf("setting interrupt index: {}\n", .{v - 32});
    int_handle_t[v - 32] = te;
}
///Allocates an interrupt vector
pub fn alloc_vector(te: *const fn (*int_regs) void) ?u16 {
    var v: u16 = 0;
    for (&int_handle_t) |*e| {
        if (v < 15) {
            v += 1;
            continue;
        }
        if (e.* == null) {
            e.* = te;
            return v + 32;
        }
        v += 1;
    }
    return null;
}
const exep_lookup_table = [_][]const u8{
    "Division fault",
    "Debug fault",
    "Non maskable interrupt",
    "Breakpoint reached",
    "Overflow trap",
    "Bound range exceeded fault",
    "Invalid opcode fault",
    "Device not available fault",
    "Double fault",
    "r0",
    "Invalid TSS fault",
    "Segment not present fault",
    "Stack segment fault",
    "general protection fault",
    "page fault",
    "r1",
    "x87 floating point exception fault",
    "alignement check fault",
    "machine check",
    "SIMD floating point exception",
    "VMM communication exception",
    "Control protection exception",
    "r2",
    "r3",
    "r4",
    "r5",
    "r6",
    "r7",
    "Hypervisor injection exception",
    "VMM communication exception",
    "Security exception",
    "r8",
    "Tripple fault",
    "r9",
};
fn exep_handle(int: *int_regs) void {
    switch (int.int_no) {
        0xe => {
            const cr2 = dump_cr2();
            dbg.printf("address of page fault: 0x{x}\n", .{cr2});
            if (@import("../paging/vmm.zig").page_fault(&@import("../../../HAL/mem/vmm.zig").home_freelist, int, cr2) == false) {
                dbg.printf("recovered.\n", .{});
                return;
            }
            tty.printf("address of page fault: 0x{x}\n", .{cr2});
        },

        else => dbg.printf("No exception handler registred\n", .{}),
    }
    dbg.printf("FOZOS CRASHED!!!\nCAUSE: {s}: 0x{x}, ERROR CODE: 0b{b}\n" ++
        "REGISTERS\nR15: 0x{x}, R14: 0x{x}, R13: 0x{x}, R12: 0x{x}, R11: 0x{x}, R10: 0x{x} R9: 0x{x} " ++
        "R8: 0x{x}\nRAX: 0x{x}, RBX: 0x{x}, RCX: 0x{x}, RDX: 0x{x}, RBP: 0x{x}, RIP: 0x{x}, RSI: 0x{x}, RSP: 0x{x}\n" ++
        "RFLAGS: 0x{x}, SS: 0x{x}, CS: 0x{x}\n", .{
        exep_lookup_table[int.int_no], int.int_no,
        int.error_code,                int.r15,
        int.r14,                       int.r13,
        int.r12,                       int.r11,
        int.r10,                       int.r9,
        int.r8,                        int.rax,
        int.rbx,                       int.rcx,
        int.rdx,                       int.rbp,
        int.rip,                       int.rsi,
        int.rsp,                       int.rflags,
        int.ss,                        int.cs,
    });

    tty.printf("FOZOS CRASHED!!!\nCAUSE: {s}: 0x{x}, ERROR CODE: 0b{b}\n" ++
        "REGISTERS\nR15: 0x{x}, R14: 0x{x}, R13: 0x{x}, R12: 0x{x}, R11: 0x{x}, R10: 0x{x} R9: 0x{x} " ++
        "R8: 0x{x}\nRAX: 0x{x}, RBX: 0x{x}, RCX: 0x{x}, RDX: 0x{x}, RBP: 0x{x}, RIP: 0x{x}, RSI: 0x{x}, RSP: 0x{x}\n" ++
        "RFLAGS: 0x{x}, SS: 0x{x}, CS: 0x{x}\n", .{
        exep_lookup_table[int.int_no], int.int_no,
        int.error_code,                int.r15,
        int.r14,                       int.r13,
        int.r12,                       int.r11,
        int.r10,                       int.r9,
        int.r8,                        int.rax,
        int.rbx,                       int.rcx,
        int.rdx,                       int.rbp,
        int.rip,                       int.rsi,
        int.rsp,                       int.rflags,
        int.ss,                        int.cs,
    });
    dbg.printf("FOZOS CRASHED!!!\nCAUSE: {s}: 0x{x}, ERROR CODE: 0b{b}\n" ++
        "REGISTERS\nR15: 0x{x}, R14: 0x{x}, R13: 0x{x}, R12: 0x{x}, R11: 0x{x}, R10: 0x{x} R9: 0x{x} " ++
        "R8: 0x{x}\nRAX: 0x{x}, RBX: 0x{x}, RCX: 0x{x}, RDX: 0x{x}, RBP: 0x{x}, RIP: 0x{x}, RSI: 0x{x}, RSP: 0x{x}\n" ++
        "RFLAGS: 0x{x}, SS: 0x{x}, CS: 0x{x}\n", .{
        exep_lookup_table[int.int_no], int.int_no,
        int.error_code,                int.r15,
        int.r14,                       int.r13,
        int.r12,                       int.r11,
        int.r10,                       int.r9,
        int.r8,                        int.rax,
        int.rbx,                       int.rcx,
        int.rdx,                       int.rbp,
        int.rip,                       int.rsi,
        int.rsp,                       int.rflags,
        int.ss,                        int.cs,
    });

    asm volatile ("cli; hlt");
}
fn dump_cr2() usize {
    return asm ("mov %[result], %cr2"
        : [result] "={rax}" (-> usize),
    );
}
pub export fn handle_int(int: *int_regs) callconv(.C) void {
    if (int.int_no < 32) {
        exep_handle(int);
    }
    if (int_handle_t[int.int_no - 32]) |handle| {
        handle(int);
    } else {
        dbg.printf("unknown interrupt: {}\n", .{int.int_no - 32});
    }

    pic.send_EOI(@truncate(int.int_no - 32));
}
extern fn idt_init() callconv(.C) void;
pub fn init() void {
    idt_init();
    for (32..32 + 16) |v| {
        bind_vector(null, @truncate(v)) orelse unreachable;
    }
}
