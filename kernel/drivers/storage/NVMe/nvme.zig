const CQeStatField = packed struct(u15) {
    stat_code: u8,
    stat_code_t: u3,
    cmd_retry_delay: u2,
    more: bool,
    do_not_retry: bool,
};
//offset 0
//made it verbose so I don't forget
const CAP = packed struct(u64) {
    max_q_entries_supported: u16,
    cont_q_required: bool,
    arbit_mech_supported: u2,
    r: u5,
    timeout: u8,
    doorbell_stride: u4,
    NVM_subsystem_reset_supported: bool,
    command_sets_supported: u8,
    boot_partition_support: bool,
    controller_power_scope: u2,
    mem_page_size_min: u4,
    mem_page_size_max: u4,
    persistent_mem_reg_supported: bool,
    controller_mem_buf_supported: bool,
    NVM_subsystem_shutdown_supported: bool,
    controller_ready_modes_supported: u2,
    NVM_subsys_shutdown_enhancements_supported: bool,
    r2: u2,
};

//TODO:  replace with actual timer
const RESET_TIMEOUT = 100000;
const Version = packed struct(u32) {
    Tertiary: u8,
    Minor: u8,
    major: u16,
};
const CmdDword = packed struct(u32) {
    opcode: u8,
    fused_op: u2 = 0,
    r: u4 = 0,
    PRPorSGL: u2 = 0,
    cmd_id: u16,
};
const SubQEntry = extern struct {
    cmd: CmdDword,
    nsid: u32 = 1,
    rsrvd: u64 = 0,
    metadata_ptr: u64 = 0,
    DatPtr1: u64,
    DatPtr2: u64 = 0,
    cmd_spec10: u32 = 0,
    cmd_spec11: u32 = 0,
    cmd_spec12: u32 = 0,
    cmd_spec13: u32 = 0,
    cmd_spec14: u32 = 0,
    cmd_spec15: u32 = 0,
};
const ControllerStatus = packed struct(u32) {
    ready: bool,
    fatal_status: bool,
    shutdown_status: u2,
    NVM_subsystem_reset_occurred: bool,
    processing_paused: bool,
    shutdown_type: bool,
    r: u25,
};
const ControllerConfig = packed struct(u32) {
    enable: bool,
    r: u3,
    command_set_selected: u3,
    mem_page_size: u4,
    arbit_mech_selected: u3,
    shutdown_notif: u2,
    io_submission_q_entry_size: u4,
    io_compl_q_entry_size: u4,
    controller_ready_independent_of_media_enable: bool,
    r2: u7,
};
const IDENTIFYResponse = extern struct {
    pci_ven_id: u16,
    pci_subsys_ven: u16,
    serial_num: [20]u8,
    model_num: [40]u8,
    firmware_revision: u64,
    RAB: u8,
    IEEE: [3]u8,
    CMIC: u8,
    max_dat_transfer_size: u8,
    CNTLID: u16,
    VER: u32,
    RTD3R: u32,
    RTD3E: u32,
    OAES: u32,
    CTRATT: u32,
    RRLS: u16,
    BPCAP: u8,
    r: u8,
    NSSL: u32,
    r2: u16,
    PLSI: u8,
    controller_type: u8,
    FGUID: [16]u8,
    CRDT1: u16,
    CRDT2: u16,
    CRDT3: u16,
    CRCAP: u8,
    r3: [118]u8,
    NVMSR: u8,
    VWCI: u8,
    MEC: u8,
    //Admin command set attributes
    OACS: u16,
    ACL: u8,
    AERL: u8,
    FRMW: u8,
    LPA: u8,
    NPSS: u8,
    AVSCC: u8,
    APSTA: u8,
    WCTEMP: u16,
    CCTEMP: u16,
    MTFA: u16,
    HMPRE: u32,
    HMMIN: u32,
    TNVMCAP: u128,
    UNVMCAP: u128,
    RPMBS: u32,
    EDSTT: u16,
    DSTO: u8,
    FWUG: u8,
    KAS: u16,
    HCTMA: u16,
    MNTMT: u16,
    MXTMT: u16,
    SANICAP: u32,
    HMMINDS: u32,
    HMMAXD: u16,
    NSETIDMAX: u16,
    ENDGIDMAX: u16,
    ANATT: u8,
    ANACAP: u8,
    ANAGRPMAX: u32,
    NANAGRPID: u32,
    PELS: u32,
    DID: u16,
    KPIOC: u8,
    r4: u8,
    MPTFAWR: u16,
    r5: u16,
    MEGCAP: u128,
    TMPTHHA: u8,
    r6: u8,
    CQT: u16,
    r7: [124]u8,
    //NVM command set attributes
    SQES: u8,
    CQES: u8,
    MAXCMD: u16,
    NN: u32,
    ONCS: u16,
    FUSES: u16,
    FNA: u8,
    VWC: u8,
    AWUN: u16,
    AWUPF: u16,
    ICSVSCC: u8,
    NWPC: u8,
    ACWU: u16,
    CDFS: u16,
    SGLS: u32,
    MNAN: u32,
    MAXDNA: u128,
    MAXCNA: u32,
    OAQD: u32,
    RHIRI: u8,
    HIRT: u8,
    CMMRTD: u16,
    NMMRTD: u16,
    MINMRTG: u8,
    MAXMRTG: u8,
    TRATTR: u8,
    r8: u8,
    MCUDMQ: u16,
    MNSUDMQ: u16,
    MCMR: u16,
    NMCMR: u16,
    MCDQPC: u16,
    r9: [180]u8,
    SUBNQN: [128:0]u16,
    // r10: [3072]u8,
    //Fabric specific ignored, since no reason to use it
};
const ComplQEntry = packed struct {
    cmd_spec: u32,
    r: u32 = 0,
    sub_q_head_ptr: u16,
    sub_q_id: u16,
    cmd_id: u16,
    phase_bit: bool,
    stat_field: CQeStatField,
};
const AQA = packed struct(u32) {
    admin_subq_size: u12,
    r: u4,
    admin_complq_size: u12,
    r2: u4,
};
const dbg = @import("../../dbg/dbg.zig");
const pci = @import("../../pci.zig");
const alloc = @import("../../../arch/x64/paging/gp_allocator.zig");
const vmm = @import("../../../arch/x64/paging/vmm.zig");
const pf = @import("../../../arch/x64/paging/pageframe_allocator.zig");
const pio = @import("../../drvlib/drvcmn.zig");
const pic = @import("../../pic/pic.zig");
const QueueEntry = struct {
    paddr: usize,
    addr: usize,
    size: usize,
    esize: u16,
    tail: u16,
};
const NVMeAdminCommandEnum = enum {
    IDENTIFY,
};
const int = @import("../../../arch/x64/interrupts/handle.zig");
const DEFAULT_ADMIN_QUEUE_SIZE = 64;
const CmdError = error{
    TimeOut,
    Fail,
};
///There will not be a lot of admin commands so I feel like we can get away with just handling one at a time
var ADMIN_AWAITING_INTERRUPT: bool = false;
pub const NVMe = struct {
    admin_sq: QueueEntry,
    admin_cq: QueueEntry,
    io_sq: QueueEntry,
    io_cq: QueueEntry,
    cap_str: usize,
    cmd_id: u16 = 0,
    base: u64,
    vbase: usize,
    isq_tail_doorbell: *volatile u32,
    icq_head_doorbell: *volatile u32,
    asq_tail_doorbell: *volatile u32,
    acq_head_doorbell: *volatile u32,
    doorbell_stride: usize,
    vector: u16,

    inline fn send_io_cmd(self: *NVMe, sqe: SubQEntry) CmdError!*ComplQEntry {
        self.cmd_id += 1;
        dbg.printf("cmd id: {}\n", .{self.cmd_id - 1});
        const t_isq_addr = self.io_sq.addr + self.io_sq.tail * @sizeOf(SubQEntry);
        const t_icq_addr = self.io_cq.addr + self.io_cq.tail * @sizeOf(ComplQEntry);
        @as(*volatile SubQEntry, @ptrFromInt(t_isq_addr)).* = sqe;
        if (self.isq_tail_doorbell.* == DEFAULT_ADMIN_QUEUE_SIZE) self.isq_tail_doorbell.* = 0;
        const completion: *volatile ComplQEntry = @ptrFromInt(t_icq_addr);
        var timeout: usize = 0;
        ADMIN_AWAITING_INTERRUPT = true;
        self.io_sq.tail += 1;
        self.isq_tail_doorbell.* = self.io_sq.tail;
        while (completion.phase_bit != true and ADMIN_AWAITING_INTERRUPT == true) {
            if (timeout == RESET_TIMEOUT) {
                dbg.printf("IO command timed out! 0x{x}, 0x{x}, icq: {x}, isq: {x}\n", .{ self.icq_head_doorbell, self.isq_tail_doorbell, self.icq_head_doorbell.*, self.isq_tail_doorbell.* });
                dbg.printf("completion: {any}\n", .{completion});
                dbg.printf("submission: {any}\n", .{@as(*SubQEntry, @ptrFromInt(t_isq_addr))});
                dbg.printf("Target isq address: 0x{x}, target icq address: 0x{x}\n", .{ t_isq_addr, t_icq_addr });
                return error.TimeOut;
            }
            timeout += 1;
        }
        self.io_cq.tail += 1;
        self.icq_head_doorbell.* += 1;
        if (@as(u15, @bitCast(completion.stat_field)) != 0) {
            dbg.printf("completion: {any}", .{completion});
            return error.Fail;
        }
        return @volatileCast(completion);
    }
    pub fn send_admin_cmd(self: *NVMe, sqe: SubQEntry) CmdError!*ComplQEntry {
        dbg.printf("cmd id: {}\n", .{self.cmd_id});
        self.cmd_id += 1;
        dbg.printf("sending admin command cq tail: {}, sq tail: {}\n", .{ self.admin_cq.tail, self.admin_sq.tail });
        const t_asq_addr: usize = self.admin_sq.addr + self.admin_sq.tail * @sizeOf(SubQEntry);
        const t_acq_addr: usize = self.admin_cq.addr + self.admin_cq.tail * @sizeOf(ComplQEntry);
        dbg.printf("asq tail doorbell: 0x{X}, acq head doorbell: 0x{X}\n", .{ self.asq_tail_doorbell, self.acq_head_doorbell });
        @as(*volatile SubQEntry, @ptrFromInt(t_asq_addr)).* = sqe;

        dbg.printf("submission: {any}\n", .{@as(*SubQEntry, @ptrFromInt(t_asq_addr))});
        dbg.printf("sending admin cmd\n", .{});
        @memset(@as(*[@sizeOf(ComplQEntry)]u8, @ptrFromInt(t_acq_addr)), 0);
        self.admin_sq.tail += 1;
        dbg.printf("tail: {}\n", .{self.admin_sq.tail});
        self.asq_tail_doorbell.* = self.admin_sq.tail;
        // dbg.printf("new doorbell: {x}\n", .{self.asq_tail_doorbell.*});
        if (self.asq_tail_doorbell.* == DEFAULT_ADMIN_QUEUE_SIZE) self.asq_tail_doorbell.* = 0;
        const completion: *volatile ComplQEntry = @ptrFromInt(t_acq_addr);
        var timeout: usize = 0;
        ADMIN_AWAITING_INTERRUPT = true;
        while (completion.phase_bit != true and ADMIN_AWAITING_INTERRUPT == true) {
            if (timeout == RESET_TIMEOUT) {
                dbg.printf("Admin command timed out! 0x{x}, 0x{x}, acq: {x}, asq: {x}\n", .{ self.acq_head_doorbell, self.asq_tail_doorbell, self.acq_head_doorbell.*, self.asq_tail_doorbell.* });
                const csts: *ControllerStatus = @ptrFromInt(self.aquire_reg(0x1C) orelse return error.Fail);
                dbg.printf("completion: {any}\ncsts: {any}\n", .{ completion, csts });
                dbg.printf("submission: {any}\n", .{@as(*SubQEntry, @ptrFromInt(t_asq_addr))});
                dbg.printf("Target asq address: 0x{x}, target acq address: 0x{x}\n", .{ t_asq_addr, t_acq_addr });
                return error.TimeOut;
            }
            timeout += 1;
        }
        if (@as(u15, @bitCast(completion.stat_field)) != 0) {
            dbg.printf("completion: {any}", .{completion});
            return error.Fail;
        }
        self.acq_head_doorbell.* += 1;
        self.admin_cq.tail += 1;
        dbg.printf("Completion: {any}", .{completion});
        dbg.printf("new completion doorbell: {}\n", .{self.acq_head_doorbell.*});
        return @volatileCast(completion);
    }
    pub fn send_IDENTIFY_CONTROLLER(self: *NVMe) ?*IDENTIFYResponse {
        const DP = pf.request_pages(1) orelse return null;
        // const MP = pf.request_pages(1) orelse return null;
        _ = self.send_admin_cmd(SubQEntry{
            .nsid = 1,
            .DatPtr1 = DP,
            .cmd = .{
                .opcode = 0x06,
                .cmd_id = self.cmd_id,
                .fused_op = 0,
                .PRPorSGL = 0,
            },
            // .metadata_ptr = MP,
            .cmd_spec10 = 1,
        }) catch |err| {
            dbg.printf("IDENTIFY FAILED {}\n", .{err});
            return null;
        };
        // dbg.printf("response: {any}\n", .{r});

        return @ptrFromInt(vmm.home_freelist.alloc_vaddr(1, DP, true, vmm.CACHE_DISABLE | vmm.PRESENT | vmm.RW) orelse return null);
    }
    ///size must be size - 1
    fn create_io_queues(self: *NVMe, queue_id: u32) CmdError!void {
        //creating io sq
        const paddr = pf.request_pages(2) orelse return error.Fail;
        const vaddr = vmm.home_freelist.alloc_vaddr(2, paddr, true, vmm.CACHE_DISABLE | vmm.PRESENT | vmm.RW | vmm.XD) orelse return error.Fail;
        // dbg.printf("creating IO completion queue\n", .{});
        _ = self.send_admin_cmd(SubQEntry{
            .cmd = .{
                .opcode = 0x5,
                .cmd_id = self.cmd_id,
            },
            .DatPtr1 = paddr + pf.PAGE_SIZE,
            .cmd_spec11 = (0 << 16) | 0b01,
            .cmd_spec10 = ((DEFAULT_ADMIN_QUEUE_SIZE - 1) << 16) | queue_id,
        }) catch |e| return e;
        self.isq_tail_doorbell = @ptrFromInt(self.vbase + 0x1000 + self.doorbell_stride * (2 * queue_id));
        self.icq_head_doorbell = @ptrFromInt(self.vbase + 0x1000 + self.doorbell_stride * (2 * queue_id + 1));
        // dbg.printf("isq tail doorbell: 0x{X}, icq tail doorbell: 0x{X}, asq tail doorbell: 0x{X}, acq head doorbell: 0x{X}\n", .{ self.isq_tail_doorbell, self.icq_head_doorbell, self.asq_tail_doorbell, self.acq_head_doorbell });
        self.io_sq.tail = 0;
        self.io_cq.tail = 0;
        self.io_sq.addr = vaddr;
        self.io_cq.addr = vaddr + pf.PAGE_SIZE;
        self.io_sq.paddr = paddr;
        self.io_cq.paddr = paddr + pf.PAGE_SIZE;
        self.io_sq.size = DEFAULT_ADMIN_QUEUE_SIZE;
        self.io_cq.size = DEFAULT_ADMIN_QUEUE_SIZE;
        self.io_sq.esize = @sizeOf(SubQEntry);
        self.io_cq.esize = @sizeOf(ComplQEntry);
        // dbg.printf("creating IO submission queue\n", .{});

        _ = self.send_admin_cmd(SubQEntry{
            .cmd = .{
                .opcode = 0x1,
                .cmd_id = self.cmd_id,
            },
            .DatPtr1 = paddr,
            .cmd_spec11 = (queue_id << 16) | 1,
            .cmd_spec10 = ((DEFAULT_ADMIN_QUEUE_SIZE - 1) << 16) | queue_id,
        }) catch |e| return e;
        // dbg.printf("cq: {any}, sq: {any}, {*}, {*}\n", .{ self.io_cq, self.io_sq, self.icq_head_doorbell, self.isq_tail_doorbell });
    }
    fn aquire_reg(self: *NVMe, offset: usize) ?usize {
        if (offset > 0x1000 * PREALLOCATED_PAGES) {
            return null;
        } else {
            return offset + self.vbase;
        }
    }
    pub fn write(self: *NVMe, lba: u64, num_b: u16, kspace: bool) CmdError!*[pf.PAGE_SIZE]u8 {
        const paddr = pf.request_pages(num_b) orelse return error.Fail;
        const vaddr = vmm.home_freelist.alloc_vaddr(num_b, paddr, kspace, vmm.CACHE_DISABLE | vmm.PRESENT | vmm.RW) orelse return error.Fail;
        const dptr1: usize = paddr;

        var dptr2: usize = paddr + pf.PAGE_SIZE;
        if (num_b == 1) {
            dptr2 = 0;
        } else @panic("TODO, BUILD PRP LISTS");
        _ = self.send_io_cmd(SubQEntry{
            .cmd = .{
                .opcode = 0x1,
                .cmd_id = self.cmd_id,
            },
            .cmd_spec10 = @truncate(lba),
            .cmd_spec11 = @truncate(lba >> 32),
            .cmd_spec12 = num_b,
            .DatPtr1 = dptr1,
            .DatPtr2 = dptr2,
        }) catch |e| return e;
        return @ptrFromInt(vaddr);
    }
    pub fn read(self: *NVMe, lba: u64, num_b: u16, kspace: bool) CmdError!*[pf.PAGE_SIZE]u8 {
        const paddr = pf.request_pages(num_b) orelse return error.Fail;
        const vaddr = vmm.home_freelist.alloc_vaddr(num_b, paddr, kspace, vmm.RW | vmm.PRESENT | vmm.CACHE_DISABLE) orelse return error.Fail;
        const dptr1: usize = paddr;

        var dptr2: usize = paddr + pf.PAGE_SIZE;
        if (num_b == 1) {
            dptr2 = 0;
        } else @panic("TODO, BUILD PRP LISTS");
        _ = self.send_io_cmd(SubQEntry{
            .cmd = .{
                .opcode = 0x2,
                .cmd_id = self.cmd_id,
            },
            .cmd_spec10 = @truncate(lba),
            .cmd_spec11 = @truncate(lba >> 32),
            .cmd_spec12 = num_b,
            .DatPtr1 = dptr1,
            .DatPtr2 = dptr2,
        }) catch |e| return e;
        return @ptrFromInt(vaddr);
    }

    inline fn setup_admin_queues(self: *NVMe) ?void {
        const paddr = pf.request_pages(2) orelse return null;
        const vaddr = vmm.home_freelist.alloc_vaddr(2, paddr, true, vmm.RW | vmm.CACHE_DISABLE | vmm.PRESENT) orelse return null;
        self.admin_sq.paddr = paddr;
        self.admin_cq.paddr = paddr + pf.PAGE_SIZE;
        self.admin_sq.esize = @sizeOf(SubQEntry);
        self.admin_sq.tail = 0;
        self.admin_cq.tail = 0;
        self.admin_sq.addr = vaddr;
        self.admin_cq.addr = vaddr + pf.PAGE_SIZE;
        self.admin_sq.size = DEFAULT_ADMIN_QUEUE_SIZE - 1;
        self.admin_cq.size = DEFAULT_ADMIN_QUEUE_SIZE - 1;
        const sqreg: *usize = @ptrFromInt(self.aquire_reg(0x28) orelse return null);
        sqreg.* = paddr;
        const cqreg: *usize = @ptrFromInt(self.aquire_reg(0x30) orelse return null);
        cqreg.* = paddr + pf.PAGE_SIZE;
        const laqa: *AQA = @ptrFromInt(self.aquire_reg(0x24) orelse return null);
        laqa.admin_subq_size = DEFAULT_ADMIN_QUEUE_SIZE - 1;
        laqa.admin_complq_size = DEFAULT_ADMIN_QUEUE_SIZE - 1;
        dbg.printf("AQA: {any}\n", .{laqa});
        const lcap: *CAP = @ptrFromInt(self.aquire_reg(0x0) orelse return null);
        dbg.printf("cqreg: 0x{x}, sqreg: 0x{x}\n", .{ cqreg.*, sqreg.* });
        self.doorbell_stride = (lcap.doorbell_stride + 2) * (lcap.doorbell_stride + 2);
        dbg.printf("doorbell stride, 0x{x}\n", .{self.doorbell_stride});
        self.asq_tail_doorbell = @ptrFromInt(self.vbase + 0x1000);
        self.acq_head_doorbell = @ptrFromInt(self.vbase + 0x1000 + self.doorbell_stride);
        dbg.printf("admin queues setup\n", .{});
    }
    inline fn register_int(self: *NVMe) ?void {
        // const intms: *u32 = @ptrFromInt(self.aquire_reg(0xC) orelse return null);
        const intmc: *u32 = @ptrFromInt(self.aquire_reg(0x10) orelse unreachable);
        self.vector = int.alloc_vector(&int_handler) orelse return null;
        dbg.printf("allocated vector : {}\n", .{self.vector});
        intmc.* |= (@as(u32, 1) << @truncate(self.vector - 32));
        pic.IRQ_clear_mask(@truncate(self.vector - 32));
        dbg.printf("allocated vector\n", .{});
    }
    pub fn int_handler(_: *int.int_regs) void {
        ADMIN_AWAITING_INTERRUPT = false;
        dbg.printf("NVMe interrupt handler called\n", .{});
    }

    inline fn reset_controller(self: *NVMe) ?void {
        // dbg.printf("Starting NVMe controller reset\n", .{});
        const cc: *ControllerConfig = @ptrFromInt(self.aquire_reg(0x14) orelse return null);
        const csts: *ControllerStatus = @ptrFromInt(self.aquire_reg(0x1C) orelse return null);
        const lCAP: *CAP = @ptrFromInt(self.aquire_reg(0x0) orelse return null);
        // dbg.printf("resetting controller\n", .{});
        // dbg.printf("CAP before reset: {any}\n", .{lCAP});
        // dbg.printf("controller status: {any}\n", .{csts});
        // dbg.printf("controller config before reset: {any}\n", .{cc});
        cc.enable = false;
        var timeout: usize = 0;
        while (csts.ready != false) {
            if (timeout == RESET_TIMEOUT) {
                dbg.printf("NVMe time out while resetting\n", .{});
                return null;
            }
            timeout += 1;
        }
        self.setup_admin_queues() orelse return null;
        cc.mem_page_size = 0;
        cc.io_compl_q_entry_size = 4;
        cc.io_submission_q_entry_size = 6;
        cc.command_set_selected = 0b110;
        cc.mem_page_size = 0;
        dbg.printf("CAP after reset: {any}\n", .{lCAP});
        cc.enable = true;
        timeout = 0;
        while (csts.ready != true) {
            if (timeout == RESET_TIMEOUT) {
                dbg.printf("controller status: {any}\n", .{csts});
                dbg.printf("controller config: {any}\n", .{cc});

                dbg.printf("NVMe time out while reenabling\n", .{});
                return null;
            }
            if (csts.fatal_status == true) {
                dbg.printf("controller status: {any}\n", .{csts});
                dbg.printf("controller config: {any}\n", .{cc});

                dbg.printf("Reenabling fatal error\n", .{});
                return null;
            }
            timeout += 1;
        }
    }
};

const PREALLOCATED_PAGES = 2;
const tty = @import("../../tty/tty.zig");
pub inline fn init(bus: u8, dev: u8) ?*NVMe {
    dbg.printf("Initialising NVMe\n", .{});
    const lNVMe: *NVMe = alloc.gl_alloc.create(NVMe) catch return null;
    const bar0: u32 = pci.config_read_dword(bus, dev, 0, pci.PCI_BAR0);
    const bar1: u32 = pci.config_read_dword(bus, dev, 0, pci.PCI_BAR1);
    // dbg.printf("bar0: 0x{X}, bar1: 0x{X}\n", .{ bar0, bar1 });
    lNVMe.base = @as(u64, @intCast(bar0 & 0xFFFFFFF0)) | (@as(u64, @intCast(bar1)) << 32);
    lNVMe.cap_str = (lNVMe.base >> 12) & 0xF;
    lNVMe.cmd_id = 0;
    // dbg.printf("cap stride: 0x{x}\n", .{lNVMe.cap_str});
    lNVMe.vbase = vmm.home_freelist.alloc_vaddr(PREALLOCATED_PAGES, lNVMe.base, true, vmm.PRESENT | vmm.CACHE_DISABLE | vmm.RW | vmm.XD) orelse return null;
    // dbg.printf("vbase: 0x{X}\n", .{lNVMe.vbase});
    lNVMe.reset_controller() orelse return null;
    const lCAP: *CAP = @ptrFromInt(lNVMe.aquire_reg(0x0) orelse return null);
    if (lCAP.command_sets_supported >> 7 != 0) {
        dbg.printf("Controller doesn't support any command set 0b{b}\n", .{lCAP.command_sets_supported});
    }
    const version: *Version = @ptrFromInt(lNVMe.aquire_reg(0x08) orelse return null);
    tty.printf("NVMe version: {}.{}.{}\n", .{ version.major, version.Minor, version.Tertiary });
    lNVMe.register_int() orelse return null;
    // dbg.printf("registered interrupt vector: {}\n", .{lNVMe.vector});
    // dbg.printf("\nNVME IDENTIFY: {any}\n", .{lNVMe.send_IDENTIFY_CONTROLLER() orelse return null});
    lNVMe.create_io_queues(1) catch |e| {
        dbg.printf("error creating io queues: {}\n", .{e});
        return null;
    };
    // dbg.printf("First block: {s}", .{lNVMe.read(0, 1, true) catch return null});
    // dbg.printf("Second block: {s}", .{lNVMe.read(1, 1, true) catch return null});
    // dbg.printf("base: 0x{X}\n", .{lNVMe.base});
    tty.printf("NVMe initialisation finished\n", .{});
    return lNVMe;
}
