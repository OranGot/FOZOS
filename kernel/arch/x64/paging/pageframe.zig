const limine = @import("limine");
const builtin = @import("builtin");
const dbg = @import("../../../drivers/dbg/dbg.zig");
pub export var five_lvl_paging_request: limine.FiveLevelPagingRequest = .{};
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
pub var kernel_PML5_table: [512]PML5_entry = undefined;
pub var kernel_PML4_table: [512]PML4_entry = undefined;
pub var kernel_PML3_table: [512]PML3_entry = undefined;
pub var kernel_PML2_table: [512]PML2_entry = undefined;
pub var kernel_PML1_table: [512]PML1_entry = undefined;
pub inline fn flush_cr3(val: u64) void {
    asm volatile ("mov %cr3, %[val]"
        :
        : [val] "{rax}" (val),
    );
}
pub const virtual_address = packed struct(u64) {
    offset: u12,
    pml1: u9,
    pml2: u9,
    pml3: u9,
    pml4: u9,
    pml5: u9,
    reserved: u7,
};
fn remap_kernel(kphybase: u64, _: u64, target_virt_base: u64) void {
    const expanded_target_address: virtual_address = @bitCast(target_virt_base);
    kernel_PML5_table[expanded_target_address.pml5] = PML5_entry{
        .present = 1,
        .addr = @truncate(@intFromPtr(&kernel_PML4_table)),
        .rw = 1,
    };
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
    var vaddr: u64 = target_virt_base;
    var phy: u64 = kphybase;
    while (vaddr < KERNEL_VHIGH) {
        const ivirt: virtual_address = @bitCast(vaddr);
        kernel_PML1_table[ivirt.pml1] = PML1_entry{
            .present = 1,
            .addr = @truncate(phy),
            .rw = 1,
        };
        vaddr += PAGE_SIZE;
        phy += PAGE_SIZE;

        if (target_virt_base + PAGE_SIZE * 512 == vaddr) @panic("kernel too big \n");
    }
    dbg.printf("cr3: 0x{x}\n", .{@intFromPtr(&kernel_PML5_table)});
    flush_cr3(@intFromPtr(&kernel_PML5_table));
    dbg.printf("cr3 flushed\n", .{});
}
pub var KERNEL_PHY_HIGH: u64 = 0;
pub var KERNEL_VBASE: u64 = 0;
pub var KERNEL_PHY_BASE: u64 = 0;
pub var KERNEL_VHIGH: u64 = 0;
pub fn setup_paging(kphybase: u64, kphy_high: u64, target_vbase: u64) void {
    dbg.printf("kphyhigh: 0x{x} kphybase: 0x{x}, target vbase: 0x{x}", .{ kphy_high, kphybase, target_vbase });
    KERNEL_PHY_HIGH = kphy_high + kphybase;
    KERNEL_VBASE = target_vbase;
    KERNEL_PHY_BASE = kphybase;
    KERNEL_VHIGH = kphy_high + target_vbase;
    dbg.printf("variables set\n", .{});
    //setting up page tables
    for (0..512) |i| {
        kernel_PML5_table[i] = PML5_entry{
            .present = 0,
        };
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
    remap_kernel(kphybase, kphy_high, target_vbase);
}
