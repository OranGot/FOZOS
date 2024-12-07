const d = @import("std").heap.GeneralPurposeAllocator(comptime config: Config)
pub const gpa_error = error{
  OutOfMemory,

};
pub const allocator_page_descriptor = packed struct {
    signature: u8 = 0xFA,
    base: u64,
    bitmap: [4096]u1
};
pub const allocator_superblock = extern struct {
    next: *allocator_superblock,
    descriptors: [7]allocator_page_descriptor,

};
pub const gp_allocator = struct {
    allocated_pages:
    pub fn init(self: gp_allocator )void{

    }
    pub fn deinit()void{

    }
};
