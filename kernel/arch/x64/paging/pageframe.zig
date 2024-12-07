const limine = @import("limine");
const builtin = @import("builtin");
const dbg = @import("../../../drivers/dbg/dbg.zig");
pub export var five_lvl_paging_request: limine.FiveLevelPagingRequest = .{};
const mmap_usable = 0;
const PML5_entry = packed struct(u64) {
    XD: u1 = 0,
    AVL2: u11 = 0,
    addr: u40 = 0,
    AVL1: u4 = 0,
    r: u1 = 0,
    AVL0: u1 = 0,
    accessed: u1 = 0,
    cache_disable: u1 = 0,
    page_write_through: u1 = 0,
    us: u1 = 0,
    rw: u1 = 1,
    present: u1,
};
const PML4_entry = packed struct(u64) {
    XD: u1 = 0,
    AVL2: u11 = 0,
    addr: u40 = 0,
    AVL1: u4 = 0,
    r: u1 = 0,
    AVL0: u1 = 0,
    accessed: u1 = 0,
    cache_disable: u1 = 0,
    page_write_through: u1 = 0,
    us: u1 = 0,
    rw: u1 = 1,
    present: u1 = 0,
};
const PML3_entry = packed struct(u64) {
    XD: u1 = 0,
    AVL2: u11 = 0,
    addr: u40 = 0,
    AVL1: u4 = 0,
    ps: u1 = 0,
    AVL0: u1 = 0,
    accessed: u1 = 0,
    cache_disable: u1 = 0,
    page_write_through: u1 = 0,
    us: u1 = 0,
    rw: u1 = 1,
    present: u1 = 0,
};
const PML2_entry = packed struct(u64) {
    XD: u1 = 0,
    AVL2: u11 = 0,
    addr: u40 = 0,
    AVL1: u4 = 0,
    ps: u1 = 0,
    AVL0: u1 = 0,
    accessed: u1 = 0,
    cache_disable: u1 = 0,
    page_write_through: u1 = 0,
    us: u1 = 0,
    rw: u1 = 1,
    present: u1 = 0,
};
const PML1_entry = packed struct(u64) {
    XD: u1 = 0,
    AVL2: u11 = 0,
    addr: u40 = 0,
    AVL1: u4 = 0,
    ps: u1 = 0,
    AVL0: u1 = 0,
    accessed: u1 = 0,
    cache_disable: u1 = 0,
    page_write_through: u1 = 0,
    us: u1 = 0,
    rw: u1 = 1,
    present: u1 = 0,
};

pub const PAGE_SIZE = 4096;
var PAGING_LVLS = 5;
var kernel_PML5_table: [512]PML5_entry = undefined;
var kernel_PML4_table: [512]PML4_entry = undefined;
var kernel_PML3_table: [512]PML3_entry = undefined;
var kernel_PML2_table: [512]PML2_entry = undefined;
var kernel_PML1_table: [512]PML1_entry = undefined;
//pub fn init() void {
//    if (!five_lvl_paging_request.response) |_| {
//        PAGING_LVLS = 4;
//    } else {
//        kernel_PML5_table = @ptrFromInt(get_cr3() & 0xFFFFFFFF_FFFFF000);
//    }
//}
pub const MappingError = error{
    PageAlreadyMapped,
};
//pub fn map_page_at_address(PML5: [*]PML5_entry) MappingError!void {
//    PML5[]
//}
pub inline fn flush_cr3(val: u64) void {
    asm volatile ("mov %cr3, %[val]"
        :
        : [val] "{rax}" (val),
    );
}
pub const virtual_address = packed struct(u64) {
    reserved: u7,
    pml5: u9,
    pml4: u9,
    pml3: u9,
    pml2: u9,
    pml1: u9,
    offset: u12,
};
fn remap_kernel(kphybase: u64, kphy_high: u64, target_virt_base: u64) void {
    dbg.printf("starting kernel remap\n", .{});
    const expanded_target_address: virtual_address = @bitCast(target_virt_base);
    dbg.printf("bit cast completed\n", .{});
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
    kernel_PML2_table[expanded_target_address.pml2] = PML2_entry{
        .present = 1,
        .addr = @truncate(@intFromPtr(&kernel_PML1_table)),
        .rw = 1,
    };
    var vaddr: u64 = target_virt_base;
    var phy: u64 = kphybase;
    while (vaddr < kphy_high + target_virt_base) {
        const ivirt: *virtual_address = @ptrCast(&vaddr);

        kernel_PML1_table[ivirt.pml1] = PML1_entry{
            .present = 1,
            .addr = @truncate(phy),
            .rw = 1,
        };

        vaddr += PAGE_SIZE;
        phy += PAGE_SIZE;
    }
    flush_cr3(@intFromPtr(&kernel_PML5_table));
}
pub fn setup_paging(kphybase: u64, kphy_high: u64, target_vbase: u64) void {

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
