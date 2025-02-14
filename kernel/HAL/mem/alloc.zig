const std = @import("std");
const target = std.Target.Cpu.Arch;
const mem = std.mem;
const dbg = @import("../../drivers/dbg/dbg.zig");
const pageframe = @import("pmm.zig");
const tty = @import("../../drivers/tty/tty.zig");
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
        // dbg.printf("running free\n", .{});
        var working_superblock: *allocator_superblock = &home_allocator_superblock;
        while (true) {
            for (&working_superblock.descriptors) |*d| {
                if (d.base >> 12 == @intFromPtr(buf.ptr) >> 12) {
                    for (@intFromPtr(buf.ptr) % pageframe.BASE_PAGE_SIZE * 8..(@intFromPtr(buf.ptr) % pageframe.BASE_PAGE_SIZE) * 8 + buf.len * 8) |v| {
                        if (get_bit_of_num(@intCast(d.bitmap[v / 8]), @truncate(v % 8)) == true) {
                            set_bit_of_num(@alignCast(@ptrCast(&d.bitmap[v / 8])), @truncate(v % 8), false);
                        } else {
                            dbg.printf("warning!!! double free\n", .{});
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
        // dbg.printf("alloc called\n", .{});
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
                    while (i < pageframe.BASE_PAGE_SIZE / 8) : (i += 1) { // NOTE: this is probably very inefficent as I use first fit
                        for (0..8) |bit| {
                            // dbg.printf("curfit: {}\n", .{curfit});
                            if (get_bit_of_num(d.bitmap[i], @truncate(bit)) == true or curfit >= len) {
                                if (curfit >= len and ptr_align == 0 or curfit >= len and mem.isAligned(d.base + i * 8 + bit, @as(usize, 1) << @truncate(ptr_align))) {
                                    // dbg.printf("ALLOC INFO: reserving vaddr\n", .{});
                                    for (i * 8 + bit - curfit..i * 8 + bit) |ii| {
                                        // dbg.printf("ii: {}", .{ii});
                                        // dbg.printf("{any}\n", .{d.bitmap});
                                        set_bit_of_num(&d.bitmap[ii / 8], @truncate(ii % 8), true);
                                    }
                                    // dbg.printf("\nALLOC INFO allocated address: 0x{X}\n", .{d.base + i * 8 + bit - curfit});

                                    return @ptrFromInt(d.base + i * 8 + bit - curfit);
                                }
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
            }
        }
    }
    pub fn resize(_: *anyopaque, buf: []u8, _: u8, new_len: usize, _: usize) bool {
        // dbg.printf("running resize\n", .{});
        var current_superblock: *allocator_superblock = &home_allocator_superblock;
        while (true) {
            for (&current_superblock.descriptors) |*d| {
                if (d.base << 12 == @intFromPtr(buf.ptr) << 12) {
                    for (@intFromPtr(buf.ptr) % pageframe.BASE_PAGE_SIZE + d.base + buf.len..@intFromPtr(buf.ptr) % pageframe.BASE_PAGE_SIZE + d.base + new_len) |s| {
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
inline fn get_bit_of_num(num: u8, bit: u8) bool {
    if ((num >> @truncate(bit)) & 1 == 1) return true else return false;
}
inline fn set_bit_of_num(num: *u8, bit: u8, state: bool) void {
    if (state == true) {
        num.* |= @as(u8, @intCast(1)) << @truncate(bit);
    } else {
        num.* &= ~(@as(u8, @intCast(1)) << @truncate(bit));
    }
}
fn alloc_pd() ?*allocator_page_descriptor {
    var cwsb = &home_allocator_superblock;
    while (true) {
        for (&cwsb.descriptors) |*d| {
            if (d.dtype == .UNDEFINED) {
                d.dtype = .FREE;
                const phy = pageframe.request_pages(1) orelse return null;
                d.base = vmm.home_freelist.alloc_vaddr(1, phy, true | vmm.RW | vmm.PRESENT) orelse return null;
                // dbg.printf("alloc_pd completed", .{});
                return d;
            }
        }
        if (cwsb.next) |n| {
            cwsb = n;
        } else return null;
    }
}
