//! VMM(Virtual Memory manager) is one of the core structures designed for keeping track of the virtual address space
//! usage. It's designed to be personal for each process
//! Organisation:
//! This is a simple linked list allocator Where each entry can represent an area of continious virtual memory
//! with a constant physical offset
const hpf = @import("../../../HAL/mem/pmm.zig");
const hal = @import("../../../HAL/mem/vmm.zig");
const pf = @import("pageframe.zig");
const palloc = @import("pageframe_allocator.zig");
const dbg = @import("../../../drivers/dbg/dbg.zig");
pub fn vaddr_to_paddr(self: *hal.VmmFreeList, vaddr: usize) ?usize {
    var current_entry: *hal.VmmFreeListEntry = &self.first.t[0];
    while (true) {
        if (current_entry.vbase <= vaddr and current_entry.len + current_entry.vbase > vaddr and current_entry.mapped == true) {
            return vaddr - current_entry.vbase + current_entry.pbase;
        }
        if (current_entry.next) |n| current_entry = n else return null;
    }
}
///finds a corresponding virtual address of the physical address
pub fn paddr_to_vaddr(self: *hal.VmmFreeList, paddr: usize) ?usize {
    var current_entry: *hal.VmmFreeListEntry = &self.first.t[0];
    var ctr: usize = 0;
    while (true) {
        if (current_entry.pbase <= paddr and current_entry.len + current_entry.pbase > paddr and current_entry.mapped != false) {
            return paddr - current_entry.pbase + current_entry.vbase;
        }
        if (current_entry.next) |n| {
            current_entry = n;
        } else return null;
        ctr += 1;
    }
}
const pio = @import("../../../drivers/drvlib/drvcmn.zig");
const pmm = @import("../../../HAL/mem/pmm.zig");
pub fn free_vaddr(self: *hal.VmmFreeList, addr: usize, pageno: usize) void {
    pio.invlpg(addr);
    const v: pf.virtual_address = @bitCast(addr);
    var t = hal.VmmFreeListEntryType.U_FREE;
    if (addr >= pf.KERNEL_VHIGH) {
        t = .K_FREE;
    }
    const pml4: [*]pf.PML4_entry = @ptrFromInt(self.paddr_to_vaddr(self.cr3) orelse {
        dbg.printf("WARNING!!!: free failed: 4\n", .{});
        return;
    });
    const pml3: [*]pf.PML3_entry = @ptrFromInt(self.paddr_to_vaddr(pml4[v.pml4].addr << 12) orelse {
        dbg.printf("WARNING!!!: free failed: {any}\n", .{pml4[v.pml4]});
        return;
    });
    const pml2: [*]pf.PML3_entry = @ptrFromInt(self.paddr_to_vaddr(pml3[v.pml3].addr << 12) orelse {
        dbg.printf("WARNING!!!: free failed: 2\n", .{});
        return;
    });
    const pml1: [*]pf.PML3_entry = @ptrFromInt(self.paddr_to_vaddr(pml2[v.pml2].addr << 12) orelse {
        dbg.printf("WARNING!!!: free failed: 1\n", .{});
        return;
    });
    // igore_pagefault = true;
    @as(*u64, @ptrCast(&pml1[v.pml1])).* = 0;
    self.insert_entry(.{
        .t = t,
        .len = pageno * pmm.BASE_PAGE_SIZE,
        .vbase = addr,
        .pbase = 0,
        .mapped = false,
    }) orelse {
        dbg.printf("WARNING!!!: free failed 0\n", .{});
        return;
    };
}
/// NOTE: this only works if page is mapped into virtual memory otherwise this fails.
/// The other reason why this could fail is if there is no more memory left
pub fn alloc_vaddr(self: *hal.VmmFreeList, pageno: usize, paddr: usize, kspace: bool, flags: usize) ?usize {
    if (pageno == 0) return null;
    // dbg.printf("allocating vaddr. pageno: {}, paddr: {}, kspace: {}, flags: 0b{b}", .{ pageno, paddr, kspace, flags });
    const pml4: [*]pf.PML4_entry = @ptrFromInt(self.paddr_to_vaddr(self.cr3) orelse return null);
    var min: pf.virtual_address = @bitCast(@as(usize, 0));
    if (kspace == true) {
        min = @bitCast(pf.KERNEL_VHIGH);
    }
    var p4e: u16 = min.pml4;
    var curfit: usize = 0;
    p4: while (p4e < 512) : (p4e += 1) {
        if (pml4[p4e].present == 1) {
            var pml3: [*]pf.PML3_entry = @ptrFromInt(self.paddr_to_vaddr(pml4[p4e].addr << 12) orelse {
                curfit = 0;
                continue :p4;
            });
            var p3e: u16 = min.pml3;
            p3: while (p3e < 512) : (p3e += 1) {
                if (pml3[p3e].present == 1) {
                    var pml2: [*]pf.PML2_entry = @ptrFromInt(self.paddr_to_vaddr(pml3[p3e].addr << 12) orelse {
                        curfit = 0;
                        continue :p3;
                    });
                    var p2e: u16 = 0;
                    p2: while (p2e < 512) : (p2e += 1) {
                        if (curfit != 0 and pml2[p2e].present == 0) { // attempt to allocate more pml2s
                            const pfpaddr = palloc.request_pages(1) orelse return null;

                            const pfvaddr = self.alloc_vaddr(1, pfpaddr, true, hal.PRESENT | hal.RW | hal.XD) orelse return null;
                            const npml1: [*]pf.PML1_entry = @ptrFromInt(pfvaddr);
                            for (0..512) |e| {
                                npml1[e] = pf.PML1_entry{
                                    .present = 0,
                                    .rw = 1,
                                };
                            }
                            pml2[p2e].present = 1;
                            pml2[p2e].addr = @truncate(pfpaddr >> 12);
                            return self.alloc_vaddr(pageno, paddr, kspace, hal.PRESENT | hal.RW | hal.XD);
                        }

                        if (pml2[p2e].present == 1) {
                            const pml2vaddr = self.paddr_to_vaddr(pml2[p2e].addr << 12) orelse {
                                curfit = 0;
                                continue :p2;
                            };
                            var pml1: [*]pf.PML1_entry = @ptrFromInt(pml2vaddr);
                            var p1e: u16 = 0;

                            p1: while (p1e < 512) : (p1e += 1) {
                                if (pml1[p1e].present == 0) {
                                    const addr = @as(usize, @bitCast(pf.virtual_address{
                                        .pml1 = @truncate(p1e),
                                        .pml2 = @truncate(p2e),
                                        .pml3 = @truncate(p3e),
                                        .pml4 = @truncate(p4e),
                                        .offset = 0,
                                    }));
                                    if (pf.make_canonical(addr) < @as(usize, @bitCast(min))) {
                                        continue :p1;
                                    }
                                    curfit += 1;
                                    if (curfit == pageno) {
                                        // dbg.printf("curfit found\n", .{});
                                        palloc.reserve_address(paddr, pageno, .OCCUPIED) orelse return null;
                                        const raddr = pf.make_canonical(addr - ((pageno - 1) << 12));
                                        //reserving the addresses on the page table

                                        self.reserve_vaddr(raddr, paddr, pageno * hpf.BASE_PAGE_SIZE, kspace) orelse return null;
                                        var i: usize = 0;
                                        var p_addr: pf.virtual_address = @bitCast(addr);
                                        while (i < pageno) {
                                            const l_addr: pf.virtual_address = @bitCast(raddr + hpf.BASE_PAGE_SIZE * i);
                                            //pio.invlpg(@as(usize, @bitCast(l_addr)));
                                            if (l_addr.pml4 != p_addr.pml4) {
                                                pml3 = @ptrFromInt(self.paddr_to_vaddr(pml4[l_addr.pml4].addr << 12) orelse return null);
                                                pml2 = @ptrFromInt(self.paddr_to_vaddr(pml3[l_addr.pml3].addr << 12) orelse return null);
                                                pml1 = @ptrFromInt(self.paddr_to_vaddr(pml2[l_addr.pml2].addr << 12) orelse return null);
                                            } else if (l_addr.pml3 != p_addr.pml3) {
                                                pml2 = @ptrFromInt(self.paddr_to_vaddr(pml3[l_addr.pml3].addr << 12) orelse return null);
                                                pml1 = @ptrFromInt(self.paddr_to_vaddr(pml2[l_addr.pml2].addr << 12) orelse return null);
                                            } else if (l_addr.pml2 != p_addr.pml2) {
                                                pml1 = @ptrFromInt(self.paddr_to_vaddr(pml2[l_addr.pml2].addr << 12) orelse return null);
                                            }
                                            if (pml1[l_addr.pml1].present == 1) {
                                                return null;
                                            }
                                            pml1[l_addr.pml1].addr = @truncate((paddr + i * hpf.BASE_PAGE_SIZE) >> 12);
                                            pml1[l_addr.pml1] = @as(pf.PML1_entry, @bitCast(@as(usize, @bitCast(pml1[l_addr.pml1])) | flags | @as(usize, @bitCast(pml1[l_addr.pml1]))));
                                            // pml1[l_addr.pml1].rw = 1;
                                            // pml1[l_addr.pml1].present = 1;
                                            i += 1;
                                            p_addr = @bitCast(@as(usize, @bitCast(p_addr)) + 1 << 12);
                                        }
                                        return raddr;
                                    }
                                } else {
                                    curfit = 0;
                                }
                            }
                            p1e = 0;
                        }
                    }

                    p2e = 0;
                }
            }
            p3e = 0;
        }
    }
    // dbg.printf("alloc failed: checked all pmls {}\n", .{curfit});
    return null;
}

pub inline fn setup(kphybase: usize, kphylen: usize) void {
    hal.home_freelist.first = &hal.first_table;
    hal.home_freelist.first.t[0] = .{
        .next = &hal.home_freelist.first.t[1],
        .len = hpf.BASE_PAGE_SIZE,
        .t = .RESTRICTED,
        .vbase = 0,
        .pbase = 0,
        .mapped = false,
    };
    hal.home_freelist.first.t[1] = .{
        .next = &hal.home_freelist.first.t[2],
        .t = .U_FREE,
        .pbase = 0,
        .len = pf.TARGET_VBASE,
        .vbase = hpf.BASE_PAGE_SIZE,
        .mapped = false,
    };
    hal.home_freelist.first.t[2] = .{
        .vbase = pf.TARGET_VBASE,
        .t = .K_OCCUPIED,
        .next = null,
        .len = kphylen + pf.DEFAULT_STACK_SIZE, //4 is for the pages mapped after the kernel for kernel tables
        .pbase = kphybase,
        .mapped = true,
    };
    // home_freelist.first.t[3] = .{
    //     .vbase = pf.TARGET_VBASE + home_freelist.first.t[2].len,
    //     .t = .K_FREE,
    //     .next = null,
    //     .pbase = 0,
    //     .mapped = false,
    //     .len = 0xFFFFFFFFFFFFFFFF - home_freelist.first.t[3].vbase ,
    // };
}
const int = @import("../interrupts/handle.zig");
pub var igore_pagefault: bool = false;
///True for non-recoverable otherwise false => return
///Some arguments are currently unused because I am planning to add on to the handler and this is just a temp version
pub fn page_fault(_: *hal.VmmFreeList, _: *int.int_regs, _: usize) bool {
    // dbg.printf("Page fault hanlder\n", .{});
    if (igore_pagefault == true) {
        igore_pagefault = false;
        return false;
    }

    return true;
}
///WARNING: slow
pub fn map_paddr_to_vaddr(self: *hal.VmmFreeList, paddr: usize, vaddr: usize, pageno: usize, flags: u64) ?void {
    const pml4: [*]pf.PML4_entry = @ptrFromInt(self.paddr_to_vaddr(self.cr3) orelse return null);
    for (0..pageno) |page| {
        const addr: pf.virtual_address = @bitCast(vaddr + page * pmm.BASE_PAGE_SIZE);
        if (pml4[addr.pml4].present == 0) {
            const p = pmm.request_pages(1) orelse return null;
            const v: [*]pf.PML3_entry = @ptrFromInt(hal.home_freelist.alloc_vaddr(1, p, true, hal.PRESENT | hal.RW) orelse return null);
            defer hal.home_freelist.free_vaddr(@intFromPtr(v), 1);
            @memset(v[0..512], @as(pf.PML3_entry, @bitCast(@as(u64, @intCast(0))))); //just in case
            pml4[addr.pml4].addr = @truncate(p >> 12);
            pml4[addr.pml4].present = 1;
            pml4[addr.pml4].rw = 1;
            pml4[addr.pml4].us = 1;
        }

        const pml3: [*]pf.PML3_entry = @ptrFromInt(self.paddr_to_vaddr(pml4[addr.pml4].addr << 12) orelse self.alloc_vaddr(1, pml4[addr.pml4].addr << 12, true, hal.RW | hal.PRESENT) orelse {
            return null;
        });
        if (pml3[addr.pml3].present == 0) {
            const p = pmm.request_pages(1) orelse return null;
            const v: [*]pf.PML2_entry = @ptrFromInt(hal.home_freelist.alloc_vaddr(1, p, true, hal.PRESENT | hal.RW) orelse return null);
            defer hal.home_freelist.free_vaddr(@intFromPtr(v), 1);
            @memset(v[0..512], @as(pf.PML2_entry, @bitCast(@as(u64, @intCast(0))))); //just in case
            pml3[addr.pml3].addr = @truncate(p >> 12);
            pml3[addr.pml3].present = 1;
            pml3[addr.pml3].rw = 1;
            pml3[addr.pml3].us = 1;
        }
        const pml2: [*]pf.PML2_entry = @ptrFromInt(self.paddr_to_vaddr(pml3[addr.pml3].addr << 12) orelse self.alloc_vaddr(1, pml3[addr.pml3].addr << 12, true, hal.RW | hal.PRESENT) orelse return null);
        // const pml2: [*]pf.PML2_entry = @ptrFromInt(self.paddr_to_vaddr(pml3[addr.pml3].addr << 12) orelse return null);
        if (pml2[addr.pml2].present == 0) {
            const p = pmm.request_pages(1) orelse return null;
            const v: [*]pf.PML1_entry = @ptrFromInt(hal.home_freelist.alloc_vaddr(1, p, true, hal.PRESENT | hal.RW) orelse return null);
            defer hal.home_freelist.free_vaddr(@intFromPtr(v), 1);
            @memset(v[0..512], @as(pf.PML1_entry, @bitCast(@as(u64, @intCast(0))))); //just in case
            pml2[addr.pml2].addr = @truncate(p >> 12);
            pml2[addr.pml2].present = 1;
            pml2[addr.pml2].rw = 1;
            pml2[addr.pml2].us = 1;
        }
        const pml1: [*]pf.PML1_entry = @ptrFromInt(self.paddr_to_vaddr(pml2[addr.pml2].addr << 12) orelse self.alloc_vaddr(1, pml2[addr.pml2].addr << 12, true, hal.RW | hal.PRESENT) orelse return null);
        // const pml1: [*]pf.PML1_entry = @ptrFromInt(self.paddr_to_vaddr(pml2[addr.pml2].addr << 12) orelse return null);
        pml1[addr.pml1].addr = @truncate((paddr + page * pmm.BASE_PAGE_SIZE) >> 12);
        pml1[addr.pml1] = @bitCast(@as(usize, @bitCast(pml1[addr.pml1])) | flags);
        self.reserve_vaddr(vaddr, paddr, pageno * pmm.BASE_PAGE_SIZE, true) orelse return null;
    }
}
///function to free the entire freelist. For the kernel area only frees the virtual address space unless the preserve kernel flag was specified. In that case it will preserve anything with type of .K_OCCUPIED
pub inline fn free_all(self: *hal.VmmFreeList, preserve_kernel: bool) void {
    var curr_table = self.first;
    while (curr_table.next != null) : (curr_table = curr_table.next.?) {
        for (curr_table.t) |e| {
            if (preserve_kernel == true and (e.t == .K_OCCUPIED or e.t == .K_FREE)) return;
            if (e.mapped == true) {
                self.free_vaddr(e.vbase, e.len / pmm.BASE_PAGE_SIZE);
            }
            if (e.vbase < pmm.KERNEL_VIRT_BASE) {
                _ = pmm.free_pages(e.pbase, e.len / pmm.BASE_PAGE_SIZE);
            }
            //TODO: this is a very bad way to do this. needs to be redone for a possibility of shared memory working after one of the processes terminates maybe idk?
        }
    }
}
