const limine = @import("limine");
const builtin = @import("builtin");
const dbg = @import("../../../drivers/dbg/dbg.zig");
//pub export var five_lvl_paging_request: limine.FiveLevelPagingRequest = .{};
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
pub const PML3_entry = packed struct(u64) {
    present: u1 = 0,
    rw: u1 = 1,
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
    rw: u1 = 1,
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
    rw: u1 = 1,
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

pub const PAGE_SIZE = 4096;
var PAGING_LVLS = 5;
//pub var kernel_PML5_table: [512]PML5_entry align(4096) = undefined;
pub var kernel_PML4_table: [512]PML4_entry align(4096) = undefined;
pub var kernel_PML3_table: [512]PML3_entry align(4096) = undefined;
pub var kernel_PML2_table: [512]PML2_entry align(4096) = undefined;
pub var kernel_PML1_table: [512]PML1_entry align(4096) = undefined;
extern fn flush_cr3(val: u64) callconv(.C) void;
//pub inline fn flush_cr3(val: u64) void {
//    dbg.printf("value passed: 0x{x}\n", .{val});
//    asm volatile ("movq %cr3, %[val]"
//        :
//        : [val] "{rax}" (val),
//    );
//}
pub const virtual_address = packed struct(u64) {
    offset: u12,
    pml1: u9,
    pml2: u9,
    pml3: u9,
    pml4: u9,
    pml5: u9,
    reserved: u7,
};
pub var HHDM_OFFSET: usize = 0;
pub export var hhdm_request: limine.HhdmRequest = .{};
fn remap_kernel(kphybase: u64) void {
    const expanded_target_address: virtual_address = @bitCast(HHDM_OFFSET);
    //kernel_PML5_table[expanded_target_address.pml5] = PML5_entry{
    //    .present = 1,
    //    .addr = @truncate(@intFromPtr(&kernel_PML4_table)),
    //    .rw = 1,
    //};
    kernel_PML4_table[expanded_target_address.pml4] = PML4_entry{
        .present = 1,
        .addr = @truncate(@intFromPtr(&kernel_PML3_table)),
        .rw = 1,
    };

    kernel_PML3_table[expanded_target_address.pml3] = PML3_entry{
        .present = 1,
        .addr = @truncate(@intFromPtr(&kernel_PML2_table)),
        .rw = 1,
    };

    dbg.printf("page tables setting\n", .{});
    kernel_PML2_table[expanded_target_address.pml2] = PML2_entry{
        .present = 1,
        .addr = @truncate(@intFromPtr(&kernel_PML1_table)),
        .rw = 1,
    };
    dbg.printf("page tables set\n", .{});
    var vaddr: u64 = HHDM_OFFSET;
    var phy: u64 = kphybase;
    var ctr: usize = 0;
    while (vaddr < KERNEL_VHIGH) {
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
        if (HHDM_OFFSET + PAGE_SIZE * 512 == vaddr) @panic("kernel too big \n");
    }
    //dbg.printf("getting initial pml5\n", .{});
    //const initial_pml5: usize = asm volatile (
    //    \\movq %cr3, %rax
    //    : [o] "=rax" (-> usize),
    //    :
    //    : "rax"
    //) & 0xFFFFFFFFFFFFF000;
    //dbg.printf("got initial pml5 0x{X}\n", .{initial_pml5});
    //const lpml5: *[512]PML5_entry = @ptrFromInt(initial_pml5);
    //const exp_addr: virtual_address = @bitCast(@intFromPtr(&kernel_PML5_table));
    //const lpml4: *[512]PML4_entry = @ptrFromInt(lpml5[exp_addr.pml5].addr);
    //const lpml3: *[512]PML3_entry = @ptrFromInt(lpml4[exp_addr.pml4].addr);

    //const lpml2: *[512]PML2_entry = @ptrFromInt(lpml3[exp_addr.pml3].addr);
    //const lpml1: *[512]PML1_entry = @ptrFromInt(lpml2[exp_addr.pml2].addr);
    const finaddr: usize = @intFromPtr(&kernel_PML4_table) - HHDM_OFFSET;
    dbg.printf("cr3 is going to be : 0x{x}. kernel PML4 table is located at 0x{x}\n", .{ finaddr, @intFromPtr(&kernel_PML4_table) });
    dump_stack_values();
    flush_cr3(finaddr);
    var cr3: usize = 0;
    asm volatile ("mov %[out], %cr3"
        : [out] "=r" (cr3),
    );

    dbg.printf("cr3 flushed: 0x{x}\n", .{cr3});
}
pub var KERNEL_PHY_HIGH: u64 = 0;
pub var KERNEL_VBASE: u64 = 0;
pub var KERNEL_PHY_BASE: u64 = 0;
pub var KERNEL_VHIGH: u64 = 0;
pub fn setup_paging(kphybase: u64, kphy_high: u64) void {
    if (hhdm_request.response) |d| {
        dbg.printf("offset is 0x{x}\n", .{d.offset});
        HHDM_OFFSET = d.offset;
    } else @panic("limine hhdm request failed");
    dbg.printf("kphyhigh: 0x{x} kphybase: 0x{x}, target vbase: 0x{x}\n", .{ kphy_high, kphybase, HHDM_OFFSET });
    KERNEL_PHY_HIGH = kphy_high + kphybase;
    KERNEL_VBASE = HHDM_OFFSET;
    KERNEL_PHY_BASE = kphybase;
    KERNEL_VHIGH = kphy_high + HHDM_OFFSET;
    dbg.printf("variables set\n", .{});
    //setting up page tables
    for (0..512) |i| {
        //kernel_PML5_table[i] = PML5_entry{
        //    .present = 0,
        //};
        kernel_PML4_table[i] = PML4_entry{
            .present = 0,
        };
        kernel_PML3_table[i] = PML3_entry{
            .present = 0,
        };
        kernel_PML2_table[i] = PML2_entry{
            .present = 0,
        };
        kernel_PML1_table[i] = PML1_entry{
            .present = 0,
        };
    }
    remap_kernel(kphybase);
}
const palloc = @import("pageframe_allocator.zig");
///This function maps extra pages after the kernel to map stack
pub fn remap_stack(size: u64) void {
    const ktop_expand: virtual_address = @bitCast(KERNEL_VHIGH);
    if (ktop_expand.pml1 + size >= 512) @panic("TODO: preallocate more pages");
    const baddr = palloc.request_pages(size, KERNEL_PHY_HIGH) catch @panic("stack remap fail.");
    for (0..size) |i| {
        kernel_PML1_table[ktop_expand.pml1 + i].present = 1;
        kernel_PML1_table[ktop_expand.pml1 + i].addr = @truncate(baddr + i * PAGE_SIZE);
    }
    dbg.printf("stack remapped to 0x{X}\n", .{(KERNEL_VHIGH + size * PAGE_SIZE)});
    asm volatile ("mov %rbp, %[kh]"
        :
        : [kh] "r" (KERNEL_VHIGH + size * PAGE_SIZE),
    );
    asm volatile ("mov %rsp, %[kh]"
        :
        : [kh] "r" (KERNEL_VHIGH + size * PAGE_SIZE),
    );
}
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
