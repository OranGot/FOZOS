//pageframe allocator allocates physical addresses
//this allocator allocates virtual addresses for use
const pageframe = @import("pageframe.zig");
const palloc = @import("pageframe_allocator.zig");
var bootstrap_PML4_table: [512]pageframe.PML4_entry = undefined;
var bootstrap_PML3_table: [512]pageframe.PML3_entry = undefined;
var bootstrap_PML2_table: [512]pageframe.PML2_entry = undefined;
var bootstrap_PML1_table: [512]pageframe.PML1_entry = undefined;
pub const vmem_list_entry_type = enum(u8) {
    OCCUPIED,
    NO_FREE_RESERVED,
    UNDEFINED,
};
const vmem_list_entry = extern struct {
    next: ?*vmem_list_entry,
    base: u64,
    high: u64,
    entry_type: vmem_list_entry_type,
};
const vmem_allocator_superblock = extern struct {
    list: [163]vmem_list_entry,
    avl: [13]u8,
    next: ?*vmem_allocator_superblock,
};
const VmemError = error{
    OutOfMemory,
    InvalidEntry,
};
pub const vmem_pageframe = struct {
    first_superblock: *vmem_allocator_superblock,
    ///creates a block of data at certain addresses while clearing the space from other blocks.
    ///NOTE: this is made to ONLY be used in the allocator
    pub fn create_block_of_t(self: *vmem_pageframe, vbase: u64, vhigh: u64, entry_type: vmem_list_entry_type) VmemError!void {
        var current_entry = self.first_superblock.list[0];
        while (true) {
            if (check_ranges_overlap(vbase, vhigh, current_entry.base, current_entry.high)) {}
            if (current_entry.next) |next| {
                current_entry = next;
            } else {
                return error.InvalidEntry;
            }
        }
    }
    pub fn allocate_pages(pageno: u32) ?[*]u8 {
        const phy = try palloc.request_pages(pageno) catch {
            return null;
        };
    }
    pub fn map_phy_to_virt(vbase: u64, pageno: u32, phy: u64) VmemError!void {}
    //NOTE: used in early boot process to allocate more page tables this is the space which was allocated while remapping kernel
    pub fn allocate_on_bootstrap() VmemError!u64 {
        var id: u16 = 0;
        for (pageframe.kernel_PML1_table) |e| {
            if (!e.present) {
                //TODO: this is not going to scale but I am going crazy so I will leave it like that.
                e.addr = @truncate(try palloc.request_pages(1) catch {
                    return error.OutOfMemory;
                });
                return pageframe.KERNEL_VHIGH & 0xFFFFFFFFFFE00000 + id << 12;
            }
            id += 1;
        }
        return error.OutOfMemory;
    }
};
fn check_ranges_overlap(t1_s: u64, t1_e: u64, t2_s: u64, t2_e: u64) bool {
    if ((t1_s >= t2_s and t1_s <= t2_e) or (t1_e >= t2_s and t1_e <= t2_e) or (t2_s >= t1_s and t2_s <= t1_e) or (t2_e >= t1_s and t2_e <= t1_e)) {
        return true;
    } else return false;
}
