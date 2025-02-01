const mem = @import("std").mem;
const dbg = @import("../../../drivers/dbg/dbg.zig");
const pageframe = @import("pageframe_allocator.zig");
const tty = @import("../../../drivers/tty/tty.zig");
const vmm = @import("vmm.zig");
pub const gpa_error = error{
    OutOfMemory,
};
pub const descriptor_type = enum(u8) { UNDEFINED = 0, FREE = 1 };
pub const allocator_page_descriptor = extern struct {
    dtype: descriptor_type = .UNDEFINED,
    base: u64 = 0,
    bitmap: [512]u8,
};
pub const allocator_superblock = extern struct {
    next: ?*allocator_superblock,
    descriptors: [7]allocator_page_descriptor,
};
var home_allocator_superblock: allocator_superblock = undefined;
pub const gp_allocator = struct {
    first_superblock: *allocator_superblock = &home_allocator_superblock,

    pub fn free(_: *anyopaque, buf: []u8, _: u8, _: usize) void {
        var working_superblock: *allocator_superblock = &home_allocator_superblock;
        while (true) {
            for (&working_superblock.descriptors) |*d| {
                if (d.base >> 12 == @intFromPtr(buf.ptr) >> 12) {
                    for (@intFromPtr(buf.ptr) % pageframe.PAGE_SIZE..@intFromPtr(buf.ptr) % pageframe.PAGE_SIZE + buf.len) |v| {
                        if (d.bitmap[v] == 1) {
                            d.bitmap[v] = 0;
                        } else {
                            // dbg.printf("warning!!! double free\n", .{});
                        }
                    }
                    return;
                }
            }
            if (working_superblock.next) |n| {
                working_superblock = n;
            } else {
                // dbg.printf("WARNING: free failed\n", .{});
                return;
            }
        }
    }
    pub fn alloc(_: *anyopaque, len: usize, ptr_align: u8, _: usize) ?[*]u8 {
        // dbg.printf("alloc called len: {} align: {}\n", .{ len, ptr_align });
        //const self: *gp_allocator = @alignCast(@ptrCast(selfo));

        var working_superblock: *allocator_superblock = &home_allocator_superblock;

        while (true) {
            for (&working_superblock.descriptors) |*d| {
                if (d.dtype == .UNDEFINED) {
                    for (0..512) |i| {
                        d.bitmap[i] = 0;
                    }
                    d.dtype = .FREE;
                    const pbase = pageframe.request_pages(1) orelse return null;
                    d.base = vmm.home_freelist.alloc_vaddr(1, pbase, true, vmm.PRESENT | vmm.RW) orelse return null;
                }
                if (d.dtype == .FREE) {
                    var curfit: usize = 0;
                    // dbg.printf("found a fitting descriptor\n", .{});
                    var i: usize = 0;
                    while (i < pageframe.PAGE_SIZE / 8) : (i += 1) { // NOTE: this is probably very inefficent as I use first fit
                        for (0..8) |bit| {
                            // dbg.printf("curfit: {}\n", .{curfit});
                            if (get_bit_of_num(d.bitmap[i], @truncate(bit)) == true or curfit >= len) {
                                if (curfit >= len and ptr_align == 0 or curfit >= len and mem.isAligned(d.base + i * 8 + bit, @as(usize, 1) << @truncate(ptr_align))) {
                                    return @ptrFromInt(d.base + i * 8 + bit - curfit);
                                } else dbg.printf("not properly aligned\n", .{});
                            } else curfit += 1;
                        }
                    }
                }
            }
            if (working_superblock.next) |next| {
                working_superblock = next;
            } else {
                // dbg.printf("found a free descriptor\n", .{});
                const phy = pageframe.request_pages(1) orelse return null;
                // dbg.printf("page request completed\n", .{});
                const addr = vmm.home_freelist.alloc_vaddr(1, phy, true, vmm.RW | vmm.PRESENT) orelse return null;
                const nb: *allocator_superblock = @ptrFromInt(addr);
                nb.next = null;

                working_superblock.next = nb;
                for (&nb.descriptors) |*d| {
                    for (0..512) |i| {
                        d.bitmap[i] = 0;
                    }
                    d.dtype = .UNDEFINED;
                    d.base = 0;
                }
                // dbg.printf("Ran out of free descriptors in superblocks \n", .{});
                // var cwblock: *allocator_superblock = &home_allocator_superblock;
                // w: while (true) {
                //     for (&cwblock.descriptors) |*d| {
                //         if (d.dtype == .UNDEFINED) {
                //             dbg.printf("found a free descriptor\n", .{});
                //             const phy = pageframe.request_pages(1) orelse return null;
                //             dbg.printf("page request completed\n", .{});
                //             const addr = vmm.home_freelist.alloc_vaddr(1, phy, true) orelse return null;
                //             //const addr = pageframe.alloc_vaddr(@import("pageframe.zig").kernel_PML4_table, true, phy, 1) catch return null;
                //
                //             dbg.printf("virtual address request completed\n", .{});
                //             d.base = @bitCast(addr);
                //             d.dtype = .FREE;
                //             break :w;
                //         }
                //     }
                //
                //     if (cwblock.next) |n| {
                //         cwblock = n;
                //     } else {
                //         const paddr = pageframe.request_pages(1) orelse return null;
                //         const vaddr = vmm.home_freelist.alloc_vaddr(1, paddr, true) orelse return null;
                //         const nsuperblock: *allocator_superblock = @ptrFromInt(vaddr);
                //         nsuperblock.next = null;
                //         for (&nsuperblock.descriptors) |*d| {
                //             d.dtype = .UNDEFINED;
                //         }
                //         cwblock.next = nsuperblock;
                //         //need to allocate more superblocks
                //         //@panic("TODO: need to allocate more superblocks.\n");
                //     }
                // }
                // return null;
                // TODO: allocate extra blocks
            }
        }
    }
    pub fn resize(_: *anyopaque, buf: []u8, _: u8, new_len: usize, _: usize) bool {
        var current_superblock: *allocator_superblock = &home_allocator_superblock;
        while (true) {
            for (&current_superblock.descriptors) |*d| {
                if (d.base << 12 == @intFromPtr(buf.ptr) << 12) {
                    for (@intFromPtr(buf.ptr) % pageframe.PAGE_SIZE + d.base + buf.len..@intFromPtr(buf.ptr) % pageframe.PAGE_SIZE + d.base + new_len) |s| {
                        if (d.bitmap[s] == 0) {
                            d.bitmap[s] = 1;
                        } else return true;
                    }
                }
            }
            if (current_superblock.next) |next| {
                current_superblock = next;
            } else {
                return false;
            }
        }
    }
};
pub var gl_alloc: mem.Allocator = undefined;
pub var allocator: gp_allocator = undefined;
pub fn init() void {
    home_allocator_superblock.next = null;
    for (&home_allocator_superblock.descriptors) |*d| {
        d.dtype = .UNDEFINED;
        for (&d.bitmap) |*b| {
            b.* = 0;
        }
    }
    const vtable = &mem.Allocator.VTable{
        .free = &gp_allocator.free,
        .alloc = &gp_allocator.alloc,
        .resize = &gp_allocator.resize,
    };
    gl_alloc = mem.Allocator{
        .ptr = &allocator,
        .vtable = vtable,
    };
}
inline fn get_bit_of_num(num: usize, bit: u8) bool {
    if ((num >> @truncate(bit)) & 1 == 1) return true else return false;
}
inline fn set_bit_of_num(num: *usize, bit: u8, state: bool) void {
    num & ~(@intFromBool(!state) << @truncate(bit));
}
fn alloc_pd() ?*allocator_page_descriptor {
    var cwsb = &home_allocator_superblock;
    while (true) {
        for (&cwsb.descriptors) |*d| {
            if (d.dtype == .UNDEFINED) {
                d.dtype = .FREE;
                const phy = pageframe.request_pages(1) orelse return null;
                d.base = vmm.home_freelist.alloc_vaddr(1, phy, true | vmm.RW | vmm.PRESENT) orelse return null;
                dbg.printf("alloc_pd completed", .{});
                return d;
            }
        }
        if (cwsb.next) |n| {
            cwsb = n;
        } else return null;
    }
}
