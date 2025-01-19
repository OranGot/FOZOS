noinline fn flush_gdt(gdtptr: usize) void {
    dbg.printf("flushing gdt with 0x{X}", .{gdtptr});
    asm volatile (
        \\lgdtq (%[p])
        :
        : [p] "r" (gdtptr),
    );
    dbg.printf("reloading segment registers\n", .{});
    asm volatile (
        \\mov $0x10, %ax
        \\mov %ax, %ds
        \\mov %ax, %es
        \\mov %ax, %fs
        \\mov %ax, %gs
        \\mov %ax, %ss
    );
    dbg.printf("reloading Code segment\n", .{});
    asm volatile (
        \\pushq $0x8
        \\leaq .reload_CS(%rip), %rax
        \\pushq %rax             
        \\lretq
        \\.reload_CS:
        //       \\lretq
        //     \\reloadCodeSeg:
    );
    @import("../../../drivers/tty/tty.zig").printf("GDT done\n", .{});
}
const dbg = @import("../../../drivers/dbg/dbg.zig");
const gdt_ptr = packed struct {
    size: u16,
    offset: u64,
};
const gdt_entry = packed struct(u64) {
    limit: u16,
    base: u16,
    base2: u8,
    access: u8,
    limit2: u4,
    flags: u4,
    base_high: u8,
};

const access_byte = packed struct(u8) {
    accessed: u1,
    rw: u1,
    dir_bit: u1,
    exe_bit: u1,
    task_or_c_or_d: u1,
    priv_lvl: u1,
    present: u1,
};
const gdt_e = packed union {
    entry_normal: gdt_entry,
    entry_long: gdt_entry_long,
};
const gdt_entry_long = packed struct {
    ext_base: u32,
    rsrvd: u32,
};
pub const TSS = packed struct {
    rsrvd: u32,
    RSP0: u64,
    RSP1: u64,
    RSP2: u64,
    rsrvd2: u64,
    IST1: u64,
    IST2: u64,
    IST3: u64,
    IST4: u64,
    IST5: u64,
    IST6: u64,
    IST7: u64,
    rsrvd3: u64,
    rsrvd4: u16,
    IOBP: u16,
};
var tss: TSS = undefined;
var gdt: [5]gdt_e = undefined;
var ptr: gdt_ptr = undefined;
// setup and forget about gdt(hopefully)
pub fn setup_gdt() void {
    asm volatile ("cli");
    dbg.printf("starting gdt setup: {}\n", .{@bitSizeOf(gdt_e)});
    setup_gate(0, 0, 0, 0, 0); //          null segment
    setup_gate(0xFFFF, 0, 0x9A, 0xA, 1); //kernel code
    setup_gate(0xFFFF, 0, 0x92, 0xC, 2); //kernel data
    setup_gate(0xFFFF, 0, 0xFA, 0xA, 3); //user code
    setup_gate(0xFFFF, 0, 0xF2, 0xC, 4); //user data
    dbg.printf("seting up long gate\n", .{});
    //    setup_long_gate(5, @sizeOf(TSS) - 1, @intFromPtr(&tss), 0x89, 0x0); //task state segment
    dbg.printf("gdt gates setup\n", .{});
    ptr = gdt_ptr{
        .offset = @intFromPtr(&gdt),
        .size = @sizeOf(gdt_e) * 5 - 1,
    };
    flush_gdt(@intFromPtr(&ptr));
}
fn setup_gate(limit: u20, base: u32, access: u8, flag: u4, entid: u8) void {
    gdt[entid].entry_normal = gdt_entry{
        .base = @truncate(base),
        .base2 = @truncate(base >> 16),
        .base_high = @truncate(base >> 24),
        .limit = @truncate(limit),
        .flags = flag,
        .limit2 = @truncate(limit >> 16),
        .access = access,
    };
}
fn setup_long_gate(baseid: u8, limit: u20, base: u64, access: u8, flag: u8) void {
    setup_gate(limit, @truncate(base), access, flag, baseid);
    if (baseid + 1 >= gdt.len) {
        dbg.printf("base id too big\n", .{});
    }
    gdt[baseid + 1] = gdt_e{ .entry_long = gdt_entry_long{
        .ext_base = @truncate(base >> 32),
        .rsrvd = 0,
    } };
}
