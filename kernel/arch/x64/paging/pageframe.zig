const limine = @import("limine");
pub export var mmap_request: limine.MemoryMapRequest = .{};
pub export var five_lvl_paging_request: limine.FiveLevelPagingRequest = .{};
const mmap_usable = 0;
pub fn init() type {
    if (mmap_request.response) |mmap_response| {
        for (0..mmap_response.entry_count) |i| {
            if (mmap_response.entries()[i] == mmap_usable) {}
        }
    }
    return struct {
        const page_size = 0;
    };
}
