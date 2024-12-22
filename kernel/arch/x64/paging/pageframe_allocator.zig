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
    next: ?*list_entry,
};
pub const header_page = extern struct {
    next: ?*header_page,
    table: [127]list_entry,
    avl: [21]u8,
};
const tty = @import("../../../drivers/tty/tty.zig");
var home_pageframe_page: header_page = undefined;
pub export var mmap_request: limine.MemoryMapRequest = .{};
pub fn print_mem() void {
    if (mmap_request.response) |r| {
        for (r.entries()) |e| {
            tty.printf("base: 0x{x} length: 0x{x}, type: {s}\n", .{ e.base, e.length, @tagName(e.kind) });
        }
    }
}
pub fn setup() void {
    var ctr: usize = 0;
    var kbase: usize = 0;
    var klen: usize = 0;
    if (mmap_request.response) |r| {
        for (r.entries()) |i| {
            home_pageframe_page.table[ctr] = list_entry{
                .next = null,
                .base = i.base,
                .high = i.base + i.length,
                .type = switch (i.kind) {
                    limine.MemoryMapEntryType.usable => list_entry_type.FREE,
                    limine.MemoryMapEntryType.acpi_reclaimable => list_entry_type.FREE,
                    limine.MemoryMapEntryType.bootloader_reclaimable => list_entry_type.FREE,
                    limine.MemoryMapEntryType.kernel_and_modules => d: {
                        klen = i.length;
                        kbase = i.base;
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
    for (ctr..127) |a| {
        home_pageframe_page.table[a].type = .UNDEFINED;
        home_pageframe_page.table[a].next = null;
    }
    dbg.printf("setting up paging kernel length: 0x{x}\n", .{klen});
    pageframe.setup_paging(kbase, klen);
}

pub const PageRequestError = error{
    OutOfMemory,
    InPageAllocFail,
};
pub const PAGE_SIZE = 4096;
pub fn request_pages(pageno: u64, base: usize) PageRequestError!usize {
    var current_node: *list_entry = &home_pageframe_page.table[0];
    var last_node: ?*list_entry = null;
    while (true) {
        dbg.printf("current node: {any}\n", .{current_node});
        if (current_node.type == .FREE and current_node.high >= base + pageno * PAGE_SIZE and (base == 0 or current_node.base <= base)) {
            return allocate_pages_in_node(pageno, current_node, last_node) catch return error.InPageAllocFail;
        }
        last_node = current_node;
        if (current_node.next) |n| {
            current_node = n;
        } else return error.OutOfMemory;
    }
}
fn allocate_pages_in_node(pageno: u64, node: *list_entry, pnode: ?*list_entry) PageRequestError!usize {
    dbg.printf("allocating pages in node", .{});
    if (node.high - node.base < PAGE_SIZE * pageno) {
        return error.OutOfMemory;
    } else if (node.high - node.base == PAGE_SIZE * pageno) {
        if (pnode != null and pnode.?.type == .OCCUPIED) {
            const ret = pnode.?.high;
            pnode.?.high = node.high;
            pnode.?.next = node.next;
            node.type = .UNDEFINED;
            dbg.printf("allocating pages in node t1\n", .{});

            return ret;
        } else if (node.next != null and node.next.?.type == .OCCUPIED) {
            dbg.printf("allocating pages in node t2\n", .{});
            const ret = node.base;
            if (pnode != null) pnode.?.next = node.next;
            node.next.?.base = node.base;
            node.type = .UNDEFINED;
            return ret;
        }
    }
    if (pnode != null and pnode.?.type == .OCCUPIED) {
        const phigh = pnode.?.high;
        pnode.?.high = node.base + pageno * PAGE_SIZE;
        node.base -= pageno * PAGE_SIZE;

        dbg.printf("allocating pages in node t3\n", .{});
        return phigh;
    }
    if (node.next != null and node.next.?.type == .OCCUPIED) {
        const ret = node.next.?.base - pageno * PAGE_SIZE;
        node.high -= pageno * PAGE_SIZE;

        dbg.printf("allocating pages in node t4\n", .{});
        return ret;
    } else {
        dbg.printf("else clause\n", .{});
        var current_page: *header_page = &home_pageframe_page;
        while (true) {
            for (&current_page.table) |*e| {
                if (e.type == .UNDEFINED) {
                    if (pnode != null) {
                        pnode.?.next = @constCast(e);
                    }
                    e.base = node.base;
                    e.high = node.base + pageno * PAGE_SIZE;
                    e.type = .RESERVED;
                    e.next = @constCast(node);

                    dbg.printf("allocating pages in node t5\n", .{});
                    return e.base;
                }
            }
            if (current_page.next) |n| {
                current_page = n;
            } else {
                dbg.printf("descriptor not found need to allocate mroe", .{});
                break;
            }
        }
        dbg.printf("allocating extra pages {} and {}\n", .{ @sizeOf(header_page), @sizeOf(list_entry) });
        //allocate extra pages here
        const new_header: *header_page = @ptrFromInt(try request_pages(1, pageframe.KERNEL_PHY_HIGH));

        dbg.printf("allocating extra pages2\n", .{});
        init_header_page(new_header);

        dbg.printf("allocating extra pages3\n", .{});
        current_page.next = new_header;
        for (&current_page.table) |*e| {
            if (e.type == .UNDEFINED) {
                if (pnode != null)
                    pnode.?.next = @constCast(e);
                e.base = node.base;
                e.high = node.base + pageno * PAGE_SIZE;
                e.type = .RESERVED;
                e.next = @constCast(node);

                dbg.printf("allocating pages in node t6\n", .{});
                return e.base;
            }
        }
    }
    return error.OutOfMemory;
}
const FreeError = error{
    PermissionDenied,
    DoubleFree,
    NoFittingPage,
};

pub fn free_pages(pageno: u64, base: u64) FreeError!void {
    var cw_list_entry: *list_entry = home_pageframe_page.table[0];
    var prev_entry: *list_entry = undefined;

    while (true) {
        if (cw_list_entry.base >> 12 == base >> 12) {
            if (cw_list_entry.type != .OCCUPIED) return error.DoubleFree;
            if (base == cw_list_entry.base and base + pageno * PAGE_SIZE == cw_list_entry.high) {
                cw_list_entry.type = .FREE;
                concat_nodes(cw_list_entry, prev_entry);
                return;
            } else if (base == cw_list_entry.base) {
                const entry = allocate_list_entry().?;
                entry.base = base + PAGE_SIZE * pageno;
                entry.type = .OCCUPIED;
                entry.high = cw_list_entry.high;
                cw_list_entry.high = base + PAGE_SIZE * pageno;
                entry.next = if (cw_list_entry.next) |e| b: {
                    break :b e;
                } else c: {
                    break :c null;
                };
                cw_list_entry.next = entry;
            }
        }
        if (cw_list_entry.next) |e| {
            prev_entry = cw_list_entry;
            cw_list_entry = e;
        } else return error.NoFittingPage;
    }
}
inline fn allocate_list_entry() ?*list_entry {
    var current_header = home_pageframe_page;
    while (true) {
        for (current_header.table) |te| {
            if (te.type == .UNDEFINED) {
                return te;
            }
        }
        if (current_header.next) |n| {
            current_header = n;
        } else {
            @panic("TODO: need to allocate more blocks");
        }
    }
}
inline fn concat_nodes(cnode: *list_entry, lnode: *list_entry) void {
    if (cnode.type == lnode.type) {
        if (cnode.next) |n| {
            if (n.type == cnode.type) {
                lnode.next = n;
                lnode.high = n.high;
                cnode.type = .UNDEFINED;
                n.type = .UNDEFINED;
                return;
            }
        }
        lnode.high = cnode.high;
        if (cnode.next) |n| {
            lnode.next = n;
        } else lnode.next = null;
        cnode.type = .UNDEFINED;
    }
    if (cnode.next) |n| {
        if (cnode.type == n.type) {
            cnode.high = n.high;
            n.type = .UNDEFINED;
            if (n.next) |nn| {
                n.next = nn;
            } else n.next = null;
            return;
        }
    }
}
pub fn init_header_page(page: *header_page) void {
    page.next = null;
    var i: usize = 0;

    while (i < 127) : (i += 1) {
        var next: *list_entry = undefined;
        if (i + 1 < 127) next = &page.table[i + 1];
        page.table[i] = list_entry{
            .next = next,
            .base = 0,
            .type = .UNDEFINED,
            .high = 0,
        };
    }
}
const MappingError = error{
    OutOfMemory,
    PageAlreadyMapped,
    PageDirNotMapped4,
    PageDirNotMapped3,
    PageDirNotMapped2,
    PageDirNotMapped1,
};

pub fn map_paddr_to_vaddr(phy: u64, virt: u64, pml5: ?[*]pageframe.PML5_entry) MappingError!void {
    const expanded_vaddr: pageframe.virtual_address = @bitCast(virt);
    var pml: [*]pageframe.PML5_entry = undefined;
    if (pml5) |e| {
        pml = e;
    } else {
        pml = pageframe.kernel_PML4_table;
    }
    if (pml[expanded_vaddr.pml5].present == 0) {
        return error.PageDirNotMapped4;
    }
    const pml4: [*]pageframe.PML4_entry = @ptrFromInt(pml[expanded_vaddr.pml5].addr);

    if (pml4[expanded_vaddr.pml4].present == 0) {
        return error.PageDirNotMapped3;
    }
    const pml3: [*]pageframe.PML3_entry = @ptrFromInt(pml4[expanded_vaddr.pml4].addr);

    if (pml4[expanded_vaddr.pml3].present == 0) {
        return error.PageDirNotMapped2;
    }
    const pml2: [*]pageframe.PML2_entry = @ptrFromInt(pml3[expanded_vaddr.pml3].addr);

    if (pml4[expanded_vaddr.pml2].present == 0) {
        return error.PageDirNotMapped1;
    }
    const pml1: [*]pageframe.PML1_entry = @ptrFromInt(pml2[expanded_vaddr.pml2].addr);
    if (pml1[expanded_vaddr.pml1].present != 1) {
        pml1[expanded_vaddr.pml1].addr = phy;
    } else return error.PageAlreadyMapped;
}
pub const VaddrAllocationError = error{
    OutOfMemory,
};

///Allocates virtual address. it will find any virtual address that is already allocated but not mapped
///if kspace is set then allocation will only happen after the kernel high on error you should allocate more pageframes but
///you already don't have any preallocated space so you shall free some pages and then allocate more
pub fn alloc_vaddr(pml: ?*[512]pageframe.PML4_entry, kspace: bool, phy: u64) VaddrAllocationError!pageframe.virtual_address {
    dbg.printf("allocating vaddr at 0x{x}\n", .{phy});
    var pml4: [*]pageframe.PML4_entry = undefined;
    if (pml) |l| {
        pml4 = l;
    } else pml4 = pageframe.kernel_PML4_table;
    const min = if (kspace == true) pageframe.KERNEL_VHIGH else 0;
    const kernel_top_expand: pageframe.virtual_address = @bitCast(min); //NOTE: misleading variable name. it's just the expanded maximum address.
    dbg.printf("4: {}, 3: {}, 2: {}, 1: {}, min: 0x{x}\n", .{ kernel_top_expand.pml4, kernel_top_expand.pml3, kernel_top_expand.pml2, kernel_top_expand.pml1, min });
    for (kernel_top_expand.pml4..512) |p4e| {
        dbg.printf("pml4 looped\n{any}\n", .{pml4[0].addr});
        if (pml4[p4e].present == 1) {
            dbg.printf("pml4 found: \n", .{});
            const pml3: [*]pageframe.PML3_entry = @ptrFromInt(pml4[p4e].addr);
            dbg.printf("pml3 aquired\n", .{});
            for (0..512) |p3e| {
                if (pml3[p3e].present == 1) {
                    dbg.printf("pml3a: 0x{x}\n", .{pml3[p3e].addr});
                    const pml2: [*]pageframe.PML2_entry = @ptrFromInt(pml3[p3e].addr);
                    for (0..512) |p2e| {
                        if (pml2[p2e].present == 1) {
                            dbg.printf("pml2a: 0x{x}\n", .{pml2[p2e].addr});
                            const pml1: [*]pageframe.PML1_entry = @ptrFromInt(pml2[p2e].addr);
                            for (0..512) |p1e| {
                                dbg.printf("p1e\n", .{});
                                if (pml1[p1e].present == 0) {
                                    pml1[p1e].present = 1;
                                    pml1[p1e].addr = @truncate(phy);
                                    //page found
                                    return pageframe.virtual_address{
                                        .pml1 = @truncate(p1e),
                                        .pml2 = @truncate(p2e),
                                        .pml3 = @truncate(p3e),
                                        .pml4 = @truncate(p4e),
                                        .reserved = 0,
                                        .offset = 0,
                                    };
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    dbg.printf("vaddr allocation fail", .{});
    return error.OutOfMemory;
}
