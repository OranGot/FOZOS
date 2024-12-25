const limine = @import("limine");
const builtin = @import("builtin");
const dbg = @import("../../../drivers/dbg/dbg.zig");
const mmap_usable = 0;
pub const PML5_entry = packed struct(u64) {
    present: u1,
    rw: u1 = 1,
    us: u1 = 0,
    page_write_through: u1 = 0,
    cache_disable: u1 = 0,
    accessed: u1 = 0,
    AVL0: u1 = 0,
    r: u1 = 0,
    AVL1: u4 = 0,
    addr: u40 = 0,
    AVL2: u11 = 0,
    XD: u1 = 0,
};
pub const PML4_entry = packed struct(u64) {
    present: u1 = 0,
    rw: u1 = 0,
    us: u1 = 0,
    page_write_through: u1 = 0,
    cache_disable: u1 = 0,
    accessed: u1 = 0,
    AVL0: u1 = 0,
    r: u1 = 0,
    AVL1: u4 = 0,
    addr: u40 = 0,
    AVL2: u11 = 0,
    XD: u1 = 0,
};
pub const PML3_entry = packed struct(u64) {
    present: u1 = 0,
    rw: u1 = 0,
    us: u1 = 0,
    page_write_through: u1 = 0,
    cache_disable: u1 = 0,
    accessed: u1 = 0,
    AVL0: u1 = 0,
    ps: u1 = 0,
    AVL1: u4 = 0,
    addr: u40 = 0,
    AVL2: u11 = 0,
    XD: u1 = 0,
};
pub const PML2_entry = packed struct(u64) {
    present: u1 = 0,
    rw: u1 = 0,
    us: u1 = 0,
    page_write_through: u1 = 0,
    cache_disable: u1 = 0,
    accessed: u1 = 0,
    AVL0: u1 = 0,
    ps: u1 = 0,
    AVL1: u4 = 0,
    addr: u40 = 0,
    AVL2: u11 = 0,
    XD: u1 = 0,
};
pub const PML1_entry = packed struct(u64) {
    present: u1 = 0,
    rw: u1 = 0,
    us: u1 = 0,
    page_write_through: u1 = 0,
    cache_disable: u1 = 0,
    accessed: u1 = 0,
    dirty: u1 = 0,
    pat: u1 = 0,
    global: u1 = 0,
    AVL1: u3 = 0,
    addr: u40 = 0,
    AVL2: u7 = 0,
    PK: u4 = 0,
    XD: u1 = 0,
};
pub const PAGE_SIZE = 4096;
var PAGING_LVLS = 5;
extern fn flush_cr3(val: u64) callconv(.C) void;
pub const virtual_address = packed struct(u64) {
    offset: u12,
    pml1: u9,
    pml2: u9,
    pml3: u9,
    pml4: u9,
    reserved: u16 = 0,
};
pub var HHDM_OFFSET: usize = 0;
const TARGET_VBASE: usize = 0xffffffff80000000;
pub export var hhdm_request: limine.HhdmRequest = .{};
fn remap_kernel(kphybase: u64, kernel_PML4_table: [*]PML4_entry, kernel_PML3_table: [*]PML3_entry, kernel_PML2_table: [*]PML2_entry, kernel_PML1_table: [*]PML1_entry) void {
    const expanded_target_address: virtual_address = @bitCast(TARGET_VBASE);
    dbg.printf("target: {any}\n", .{expanded_target_address});
    kernel_PML4_table[expanded_target_address.pml4] = PML4_entry{
        .present = 1,
        .addr = @truncate(@intFromPtr(kernel_PML3_table) - HHDM_OFFSET),
        .rw = 1,
    };
    dbg.printf("kplm4: {any}\n", .{kernel_PML4_table[expanded_target_address.pml4]});
    kernel_PML3_table[expanded_target_address.pml3] = PML3_entry{
        .present = 1,
        .addr = @truncate(@intFromPtr(kernel_PML2_table) - HHDM_OFFSET),
        .rw = 1,
    };

    dbg.printf("kplm3: {any}\n", .{kernel_PML3_table[expanded_target_address.pml3]});
    kernel_PML2_table[expanded_target_address.pml2] = PML2_entry{
        .present = 1,
        .addr = @truncate(@intFromPtr(kernel_PML1_table) - HHDM_OFFSET),
        .rw = 1,
    };
    dbg.printf("kplm2: {any}\n", .{kernel_PML2_table[expanded_target_address.pml2]});
    dbg.printf("page tables set\n", .{});
    var vaddr: u64 = TARGET_VBASE;
    var phy: u64 = kphybase;
    var ctr: usize = 0;
    while (vaddr <= KERNEL_VHIGH) {
        dbg.printf("loaded vaddr: 0x{x}", .{vaddr});
        const ivirt: virtual_address = @bitCast(vaddr);
        kernel_PML1_table[ivirt.pml1] = PML1_entry{
            .present = 1,
            .addr = @truncate(phy),
            .rw = 1,
        };
        vaddr += PAGE_SIZE;
        phy += PAGE_SIZE;
        //dbg.printf("entry: {} at PML1[{}]\n", .{ ctr, ivirt.pml1 });
        ctr += 1;
        if (TARGET_VBASE + PAGE_SIZE * 512 == vaddr) @panic("kernel too big \n");
    }
}
const tty = @import("../../../drivers/tty/tty.zig");
pub var KERNEL_PHY_HIGH: u64 = 0;
pub var KERNEL_VBASE: u64 = 0;
pub var KERNEL_PHY_BASE: u64 = 0;
pub var KERNEL_VHIGH: u64 = 0;
pub fn setup_paging(kphybase: u64, kphy_high: u64) void {
    dbg.printf("PML4: {}, 3: {}, 2: {}, 1: {}", .{ @bitSizeOf(PML4_entry), @bitSizeOf(PML3_entry), @bitSizeOf(PML2_entry), @bitSizeOf(PML1_entry) });
    if (hhdm_request.response) |d| {
        dbg.printf("offset is 0x{x}\n", .{d.offset});
        HHDM_OFFSET = d.offset;
    } else @panic("limine hhdm request failed");
    dbg.printf("kphyhigh: 0x{x} kphybase: 0x{x}, target vbase: 0x{x}\n", .{ kphy_high, kphybase, TARGET_VBASE });
    KERNEL_PHY_HIGH = kphy_high + kphybase;
    KERNEL_VBASE = TARGET_VBASE;
    KERNEL_PHY_BASE = kphybase;
    KERNEL_VHIGH = kphy_high + TARGET_VBASE;
    const pbase = palloc.request_pages(4, 0) catch |e| {
        tty.printf("allocatioin error: {}\n", .{e});
        @panic("Initial pml allocations failed");
    };
    var kernel_PML1_table: [*]PML1_entry = @ptrFromInt(pbase + HHDM_OFFSET);
    var kernel_PML2_table: [*]PML2_entry = @ptrFromInt(pbase + PAGE_SIZE + HHDM_OFFSET);
    var kernel_PML3_table: [*]PML3_entry = @ptrFromInt(pbase + PAGE_SIZE * 2 + HHDM_OFFSET);
    var kernel_PML4_table: [*]PML4_entry = @ptrFromInt(pbase + PAGE_SIZE * 3 + HHDM_OFFSET);
    //setting up page tables
    for (0..512) |i| {
        kernel_PML4_table[i] = PML4_entry{
            .present = 0,
            .rw = 1,
        };
        kernel_PML3_table[i] = PML3_entry{
            .present = 0,
            .rw = 1,
        };
        kernel_PML2_table[i] = PML2_entry{
            .present = 0,
            .rw = 1,
        };
        kernel_PML1_table[i] = PML1_entry{
            .present = 0,
            .rw = 1,
        };
    }
    remap_kernel(kphybase, kernel_PML4_table, kernel_PML3_table, kernel_PML2_table, kernel_PML1_table);
    dbg.printf("cr3 is going to be : 0x{x}. kernel PML4 table is located at 0x{x}\n", .{ pbase + PAGE_SIZE * 3, @intFromPtr(kernel_PML4_table) });
    flush_cr3(pbase + PAGE_SIZE * 3);
    dbg.printf("cr3 flushed!\n", .{});
}
const palloc = @import("pageframe_allocator.zig");
///This function maps extra pages after the kernel to map stack
// pub fn remap_stack(size: u64) void {
//     const ktop_expand: virtual_address = @bitCast(KERNEL_VHIGH);
//     if (ktop_expand.pml1 + size >= 512) @panic("TODO: preallocate more pages");
//     const baddr = palloc.request_pages(size, KERNEL_PHY_HIGH) catch @panic("stack remap fail.");
//     for (0..size) |i| {
//         kernel_PML1_table[ktop_expand.pml1 + i].present = 1;
//         kernel_PML1_table[ktop_expand.pml1 + i].addr = @truncate(baddr + i * PAGE_SIZE);
//     }
//     dbg.printf("stack remapped to 0x{X}\n", .{(KERNEL_VHIGH + size * PAGE_SIZE)});
//     asm volatile ("mov %rbp, %[kh]"
//         :
//         : [kh] "r" (KERNEL_VHIGH + size * PAGE_SIZE),
//     );
//     asm volatile ("mov %rsp, %[kh]"
//         :
//         : [kh] "r" (KERNEL_VHIGH + size * PAGE_SIZE),
//     );
// }
pub fn get_phy_from_virt() void {}
pub inline fn dump_stack_values() void {
    var rbp: usize = 0;
    var rsp: usize = 0;
    asm volatile ("mov %rbp, %[out]"
        : [out] "=r" (rbp),
    );
    asm volatile ("mov %rbp, %[out]"
        : [out] "=r" (rsp),
    );
    dbg.printf("rbp: 0x{x}, rsp: 0x{x}\n", .{ rbp, rsp });
}
