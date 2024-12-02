const idtr = packed struct {
    limit: u16,
    base: *const idt_entry,
};
const idt_entry = packed struct {
    offset1: u16,
    seg_select: u16,
    ist: u8 = 0,
    attrib: u8,
    offset2: u16,
    offset3: u32,
    r1: u32 = 0,
};
const pio = @import("../../../drivers/drvlib/drvcmn.zig");

const dbg = @import("../../../drivers/dbg/dbg.zig");
const pic = @import("../../../drivers/pic/pic.zig");
const tty = @import("../../../drivers/tty/tty.zig");

const int_push_regs = struct {
    r15: u64 = 0,
    r14: u64 = 0,
    r13: u64 = 0,
    r12: u64 = 0,
    r11: u64 = 0,
    r10: u64 = 0,
    r9: u64 = 0,
    r8: u64 = 0,
    rbp: u64 = 0,
    rdi: u64 = 0,
    rsi: u64 = 0,
    rdx: u64 = 0,
    rcx: u64 = 0,
    rbx: u64 = 0,
    rax: u64 = 0,
    ecode: u64,
    int_num: u64,
    rip: u64,
    code_seg: u64,
    rflags: u64,
    orig_rsp: u64,
    ss: u64,
};
fn exep_handler(int: *int_push_regs) void {
    switch (int.int_num) {
        else => {},
    }
    tty.printf("FOZOS EXCEPTION NUMBER {}\nError code 0b{b}, code seg: {}, orig rsp: {}\n" ++
        "RFLAGS: 0b{b}\n", .{
        int.int_num,
        int.ecode,
        int.code_seg,
        int.orig_rsp,
        int.rflags,
    });
    asm volatile ("cli; hlt");
    //kills the thing
}

export fn int_handler(int: *int_push_regs) callconv(.C) void {
    dbg.printf("interrupt\n", .{});
    switch (int.int_num) {
        0...31 => exep_handler(int),
        32 => {}, //pit interrupt
        else => dbg.printf("unknown interrupt number {}\n", .{int.int_num}),
    }
    pic.send_EOI(@truncate(int.int_num));
}
fn set_descriptor(vector: usize, isr: *anyopaque, flags: u8) void {
    var entry: *idt_entry = &idt[vector];
    entry.attrib = flags;
    entry.offset1 = @as(u16, @truncate(@intFromPtr(isr)));
    entry.offset2 = @as(u16, @truncate(@intFromPtr(isr) >> 16));
    entry.offset3 = @as(u32, @truncate(@intFromPtr(isr) >> 32));
    entry.ist = 0;
    entry.seg_select = 0x8;
}
const IDT_MAX_DESCRIPTORS = 256;
var idt: [IDT_MAX_DESCRIPTORS]idt_entry align(256) = undefined;
var idtr_inst: idtr = undefined;
extern var isr_stub_table: [*]*anyopaque;
pub fn initidt() void {
    idtr_inst.base = &idt[0];
    idtr_inst.limit = (@sizeOf(idt_entry) * IDT_MAX_DESCRIPTORS) - 1;

    for (0..IDT_MAX_DESCRIPTORS) |i| {
        set_descriptor(i, isr_stub_table[i], 0x8E);
    }

    dbg.printf("idtr at 0x{x}\nidtr base: 0x{x} limit: 0x{x}\n", .{
        @intFromPtr(&idtr_inst),
        @intFromPtr(idtr_inst.base),
        idtr_inst.limit,
    });
    asm volatile (
        \\lidt (%[idtr_inst])
        :
        : [idtr_inst] "r" (&idtr_inst),
    );
}
