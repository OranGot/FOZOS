const mem = @import("std").mem;
const dbg = @import("../../../drivers/dbg/dbg.zig");
const pageframe = @import("pageframe_allocator.zig");
const tty = @import("../../../drivers/tty/tty.zig");
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
                            dbg.printf("warning!!! double free\n", .{});
                        }
                    }
                    return;
                }
            }
            if (working_superblock.next) |n| {
                working_superblock = n;
            } else {
                dbg.printf("WARNING: free failed\n", .{});
                return;
            }
        }
    }
    pub fn alloc(_: *anyopaque, len: usize, ptr_align: u8, _: usize) ?[*]u8 {
        dbg.printf("alloc called {} {}\n", .{ @sizeOf(allocator_page_descriptor), @sizeOf(allocator_superblock) });
        //const self: *gp_allocator = @alignCast(@ptrCast(selfo));

        var working_superblock: *allocator_superblock = &home_allocator_superblock;
        var curfit: usize = 0;

        while (true) {
            for (working_superblock.descriptors) |d| {
                if (d.dtype == .FREE) {
                    dbg.printf("found a fitting descriptor\n", .{});
                    var i: usize = 0;
                    while (i < pageframe.PAGE_SIZE) : (i += 1) { // NOTE: this is probably very inefficent as I use first fit
                        if (d.bitmap[pageframe.PAGE_SIZE % i] == 1) {
                            if (curfit >= len and mem.isAligned(d.base + i, @as(u64, 1) << @truncate(ptr_align))) {
                                return @ptrFromInt(d.base + i - curfit);
                            }
                            curfit = 0;
                        } else curfit += 1;
                    }
                }
            }
            if (working_superblock.next) |next| {
                dbg.printf("next superblock found", .{});
                working_superblock = next;
            } else {
                dbg.printf("Ran out of free descriptors in superblocks \n", .{});
                var cwblock: *allocator_superblock = &home_allocator_superblock;
                while (true) {
                    for (&cwblock.descriptors) |*d| {
                        if (d.dtype == .UNDEFINED) {
                            dbg.printf("found a free descriptor\n", .{});
                            const phy = pageframe.request_pages(1, @import("pageframe.zig").KERNEL_PHY_HIGH) catch {
                                return null;
                            };
                            dbg.printf("page request completed\n", .{});
                            const addr = pageframe.alloc_vaddr(null, true, phy) catch return null;

                            dbg.printf("virtual address request completed\n", .{});
                            d.base = @bitCast(addr);
                            d.dtype = .FREE;
                        }
                    }

                    if (cwblock.next) |n| {
                        cwblock = n;
                    } else {
                        //need to allocate more superblocks
                        @panic("TODO: need to allocate more superblocks.\n");
                    }
                }
                return null;
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
pub var allocator: gp_allocator = undefined;
pub fn init() mem.Allocator {
    home_allocator_superblock.next = null;
    for (&home_allocator_superblock.descriptors) |*d| {
        d.dtype = .UNDEFINED;
        d.base = 0;
        for (&d.bitmap) |*b| {
            b.* = 0;
        }
    }
    const vtable = &mem.Allocator.VTable{
        .free = &gp_allocator.free,
        .alloc = &gp_allocator.alloc,
        .resize = &gp_allocator.resize,
    };
    return mem.Allocator{
        .ptr = &allocator,
        .vtable = vtable,
    };
}
