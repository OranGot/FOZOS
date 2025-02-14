const target = @import("builtin").target.cpu.arch;
const std = @import("std");
pub const BASE_PAGE_SIZE = switch (target) {
    .x86_64 => 0x1000,
    else => @compileError("Unsupported arch"),
};
pub const KERNEL_VIRT_BASE = switch (target) {
    .x86_64 => 0xffffffff80000000,
    else => @compileError("Unsupported arch"),
};
pub fn request_pages(pageno: u64) ?usize {
    switch (target) {
        .x86_64 => return @import("../../arch/x64/paging/pageframe_allocator.zig").request_pages(pageno),
        else => @compileError("Unsupported arch"),
    }
}

pub fn free_pages(base: usize, pageno: u64) ?void {
    switch (target) {
        .x86_64 => return @import("../../arch/x64/paging/pageframe_allocator.zig").free_pages(pageno, base),
        else => @compileError("Unsupported arch"),
    }
}
