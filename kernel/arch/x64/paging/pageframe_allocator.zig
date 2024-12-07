const limine = @import("limine");
const pageframe = @import("pageframe.zig");
const dbg = @import("../../../drivers/dbg/dbg.zig");

pub const list_entry_type = enum(u8) {
    FREE = 0,
    RESERVED = 1,
    NO_FREE_RESERVED = 2,
    OCCUPIED = 3,
    UNDEFINED = 4,
};
pub const list_entry = extern struct {
    base: u64,
    high: u64,
    type: list_entry_type = list_entry_type.UNDEFINED,
    next: *list_entry = undefined,
};
pub const header_page = extern struct {
    //next: *header_page = null,
    table: [163]list_entry,
    avl: [21]u8,
};

var home_pageframe_page: header_page = undefined;
pub export var mmap_request: limine.MemoryMapRequest = .{};
pub fn setup() void {
    if (mmap_request.response) |r| {
        var ctr: usize = 0;
        for (r.entries()) |i| {
            home_pageframe_page.table[ctr] = list_entry{
                .base = i.base,
                .high = i.base + i.base,
                .type = switch (i.kind) {
                    limine.MemoryMapEntryType.usable => list_entry_type.FREE,
                    limine.MemoryMapEntryType.acpi_reclaimable => list_entry_type.FREE,
                    limine.MemoryMapEntryType.bootloader_reclaimable => list_entry_type.FREE,
                    limine.MemoryMapEntryType.kernel_and_modules => d: {
                        pageframe.setup_paging(i.base, i.length, 0xffffffff80000000);
                        dbg.printf("paging set up\n", .{});
                        break :d list_entry_type.NO_FREE_RESERVED;
                    },
                    else => list_entry_type.NO_FREE_RESERVED,
                },
            };
            if (ctr != 0) {
                home_pageframe_page.table[ctr - 1].next = &home_pageframe_page.table[ctr];
            }
            ctr += 1;
        }
    }
}
