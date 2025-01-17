const limine = @import("limine");
const builtin = @import("builtin");
const dbg = @import("../../../drivers/dbg/dbg.zig");
const mmap_usable = 0;
const vmm = @import("vmm.zig");
pub const DEFAULT_STACK_SIZE = PAGE_SIZE * 12;
export var limine_stack_request: limine.StackSizeRequest = .{ .stack_size = DEFAULT_STACK_SIZE }; //64 KiB of stack space
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
extern fn flush_cr3(usize, rbp: usize, rsp: usize) callconv(.C) void;
pub const virtual_address = packed struct(u64) {
    offset: u12,
    pml1: u9,
    pml2: u9,
    pml3: u9,
    pml4: u9,
    reserved: u16 = 0,
};
pub fn is_canonical(vaddr: usize) bool {
    const exp: virtual_address = @bitCast(vaddr);
    if (exp.pml4 >> 8 == 1) {
        if (exp.reserved == 0xFFFF) return true else return false;
    } else if (exp.reserved == 0) return true else return false;
}
pub fn make_canonical(vaddr: usize) usize {
    var exp: virtual_address = @bitCast(vaddr);
    if (exp.pml4 >> 8 == 1)
        exp.reserved = 0xFFFF
    else
        exp.reserved = 0;
    return @bitCast(exp);
}
pub var kernel_PML1_table: [*]PML1_entry = undefined;
pub var kernel_PML2_table: [*]PML2_entry = undefined;
pub var kernel_PML3_table: [*]PML3_entry = undefined;
pub var kernel_PML4_table: [*]PML4_entry = undefined;

pub var HHDM_OFFSET: usize = 0;
pub const TARGET_VBASE: usize = 0xffffffff80000000;
pub export var hhdm_request: limine.HhdmRequest = .{};
fn remap_kernel(kphybase: u64) void {
    const expanded_target_address: virtual_address = @bitCast(TARGET_VBASE);
    dbg.printf("target: {any}\n", .{expanded_target_address});
    kernel_PML4_table[expanded_target_address.pml4] = PML4_entry{
        .present = 1,
        .addr = @truncate((@intFromPtr(kernel_PML3_table) - HHDM_OFFSET) >> 12),
        .rw = 1,
    };
    dbg.printf("kplm4: {any}\n", .{kernel_PML4_table[expanded_target_address.pml4]});
    kernel_PML3_table[expanded_target_address.pml3] = PML3_entry{
        .present = 1,
        .addr = @truncate((@intFromPtr(kernel_PML2_table) - HHDM_OFFSET) >> 12),
        .rw = 1,
    };

    dbg.printf("kplm3: {any}\n", .{kernel_PML3_table[expanded_target_address.pml3]});
    kernel_PML2_table[expanded_target_address.pml2] = PML2_entry{
        .present = 1,
        .addr = @truncate((@intFromPtr(kernel_PML1_table) - HHDM_OFFSET) >> 12),
        .rw = 1,
    };
    dbg.printf("kplm2: {any}\n", .{kernel_PML2_table[expanded_target_address.pml2]});
    dbg.printf("page tables set\n", .{});
    var vaddr: u64 = TARGET_VBASE;
    var phy: u64 = kphybase;
    var ctr: usize = 0;
    while (vaddr <= KERNEL_VHIGH) {
        const ivirt: virtual_address = @bitCast(vaddr);
        kernel_PML1_table[ivirt.pml1] = PML1_entry{
            .present = 1,
            .addr = @truncate(phy >> 12),
            .rw = 1,
        };
        vaddr += PAGE_SIZE;
        phy += PAGE_SIZE;
        ctr += 1;
        if (TARGET_VBASE + PAGE_SIZE * 512 == vaddr) @panic("kernel too big \n");
    }
}
const tty = @import("../../../drivers/tty/tty.zig");
pub var KERNEL_PHY_HIGH: u64 = 0;
pub var KERNEL_VBASE: u64 = 0;
pub var KERNEL_PHY_BASE: u64 = 0;
pub var KERNEL_VHIGH: u64 = 0;
pub inline fn setup_paging(kphybase: u64, kphy_high: u64) void {
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
    const pbase = palloc.request_pages(4) orelse {
        @panic("Initial pml allocations failed");
    };
    dbg.printf("pbase: 0x{X}\n", .{pbase});
    kernel_PML1_table = @ptrFromInt(pbase + HHDM_OFFSET);
    kernel_PML2_table = @ptrFromInt(pbase + PAGE_SIZE + HHDM_OFFSET);
    kernel_PML3_table = @ptrFromInt(pbase + PAGE_SIZE * 2 + HHDM_OFFSET);
    kernel_PML4_table = @ptrFromInt(pbase + PAGE_SIZE * 3 + HHDM_OFFSET);
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
    remap_kernel(kphybase);
    dbg.printf("cr3 is going to be : 0x{x}. kernel PML4 table is located at 0x{x}\n", .{ pbase + PAGE_SIZE * 3, @intFromPtr(kernel_PML4_table) });
    //dump_stack_values();
    if (limine_stack_request.response == null) @panic("LIMINE STACK REQUEST FAIL. You probably don't have enough memory for it\n");
    const base = get_stack_base();
    const ptr = get_stack_ptr();
    //after this I can't modify the stack. this is not good but works. TODO: change that to maybe a single assebly block
    const stack_base = map_stack(DEFAULT_STACK_SIZE / PAGE_SIZE, base);
    const stack_ptr = stack_base - (base - ptr);
    KERNEL_VHIGH += DEFAULT_STACK_SIZE;
    map_ktables(pbase);
    vmm.home_freelist.cr3 = pbase + PAGE_SIZE * 3;
    flush(pbase + PAGE_SIZE * 3, stack_base, stack_ptr);
    dbg.printf("cr3 flushed!\n", .{});
}
inline fn map_ktables(pbase: usize) void {
    dbg.printf("mapping ktables\n", .{});
    vmm.home_freelist.reserve_vaddr(KERNEL_VHIGH, pbase, PAGE_SIZE * 4, true, true) orelse @panic("RESERVE VADDR FAILED\n");
    _ = @call(.always_inline, vmm.VmmFreeList.reserve_vaddr, .{ &vmm.home_freelist, KERNEL_VHIGH, pbase, PAGE_SIZE * 4, true, true }) orelse @panic("RESERVE VADDR FAILED!\n");
    const exp_khigh: virtual_address = @bitCast(KERNEL_VHIGH);
    for (0..4) |e| {
        kernel_PML1_table[exp_khigh.pml1 + e].present = 1;
        kernel_PML1_table[exp_khigh.pml1 + e].rw = 1;
        kernel_PML1_table[exp_khigh.pml1 + e].addr = @truncate((pbase + e * PAGE_SIZE) >> 12);
    }
    kernel_PML1_table = @ptrFromInt(KERNEL_VHIGH);
    kernel_PML2_table = @ptrFromInt(KERNEL_VHIGH + PAGE_SIZE * 2);
    kernel_PML3_table = @ptrFromInt(KERNEL_VHIGH + PAGE_SIZE * 3);
    kernel_PML4_table = @ptrFromInt(KERNEL_VHIGH + PAGE_SIZE * 4);
    KERNEL_VHIGH += PAGE_SIZE * 4;
}
// inline fn map_framebuffer(fbstart: usize, fblen: usize) void {
//     dbg.printf("fbstart: 0x{x}, fblen: 0x{x}\n", .{ fbstart, fblen });
//     var offset: u32 = 0;
//     if (@as(virtual_address, @bitCast(KERNEL_VHIGH + DEFAULT_STACK_SIZE)).pml2 != @as(virtual_address, @bitCast(KERNEL_VHIGH + DEFAULT_STACK_SIZE + fblen)).pml2) {}
//     for (@as(virtual_address, @bitCast(KERNEL_VHIGH + DEFAULT_STACK_SIZE)).pml1..@as(virtual_address, @bitCast(KERNEL_VHIGH + DEFAULT_STACK_SIZE + fblen)).pml1) |i| {
//         dbg.printf("i: {}\n", .{i});
//         kernel_PML1_table[i] = PML1_entry{ .present = 1, .addr = @truncate(((fbstart) >> 12) + offset) };
//         offset += 1;
//     }
//     dbg.printf("s\n", .{});
//     tty.framebuffer.address = @ptrFromInt((KERNEL_VHIGH + DEFAULT_STACK_SIZE) + (@intFromPtr(tty.framebuffer.address) - HHDM_OFFSET - fbstart));
//     dbg.printf("address: 0x{x}", .{@intFromPtr(tty.framebuffer.address)});
// }
inline fn flush(cr3: usize, rbp: usize, rsp: usize) void {
    asm volatile (
        \\movq %[cr3], %cr3
        \\movq %[rbp], %rbp
        \\movq %[rsp], %rsp
        :
        : [cr3] "r" (cr3),
          [rbp] "r" (rbp),
          [rsp] "r" (rsp),
        : "cr3", "rsp", "rbp"
    );
}
fn map_stack(pno: usize, base: usize) usize {
    dump_stack_values();
    const phybase = base - HHDM_OFFSET; //since stack is in the bootloader reclaimable area we can subtract the hhdm offset
    const expanded_vhigh: virtual_address = @bitCast(KERNEL_VHIGH);
    palloc.reserve_address(phybase - pno * PAGE_SIZE, pno, .NO_FREE_RESERVED) orelse @panic("Can't reserve stack's address. this really shouldn't happen\n");
    var stack_page = phybase - pno * PAGE_SIZE;
    for (expanded_vhigh.pml1..expanded_vhigh.pml1 + pno) |i| {
        if (i == 255) @panic("kernel too big, can't allocate stack");
        kernel_PML1_table[i] = PML1_entry{
            .present = 1,
            .rw = 1,
            .addr = @truncate(stack_page >> 12),
        };
        //dbg.printf("pml1 entry: {any}\n", .{kernel_PML1_table[i]});
        //dbg.printf("stack page = 0x{x}\n", .{stack_page});
        stack_page += PAGE_SIZE;
    }
    return KERNEL_VHIGH + pno * PAGE_SIZE;
}
const palloc = @import("pageframe_allocator.zig");
pub inline fn get_stack_base() usize {
    var rbp: usize = 0;
    asm volatile ("mov %rbp, %[out]"
        : [out] "=r" (rbp),
    );
    return rbp;
}
pub inline fn get_stack_ptr() usize {
    var rsp: usize = 0;
    asm volatile ("mov %rsp, %[out]"
        : [out] "=r" (rsp),
    );
    return rsp;
}
pub inline fn dump_stack_values() void {
    var rbp: usize = 0;
    var rsp: usize = 0;
    asm volatile ("mov %rbp, %[out]"
        : [out] "=r" (rbp),
    );
    asm volatile ("mov %rsp, %[out]"
        : [out] "=r" (rsp),
    );
    dbg.printf("rbp: 0x{x}, rsp: 0x{x}\n", .{ rbp, rsp });
}
