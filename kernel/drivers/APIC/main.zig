pub const APICRegs = extern struct {
    r: u128,
    LAPIC_ID: u32 align(16),
    LAPIC_version: u32 align(16),
    r2: [3]u128,
    task_priority_regs: u32 align(16),
    arbitration_priority_register: u32 align(16),
    proc_priority_reg: u32 align(16),
    eoi_reg: u32 align(16),
    remote_read_reg: u32 align(16),
    logical_dest_reg: u32 align(16),
    dest_fmt_reg: u32 align(16),
    spurious_int_vector_reg: u32 align(16),
    ISR: [8]u32 align(16),
    TMR: [8]u32 align(16),
    int_req_reg: [8]u32 align(16),
    err_stat_reg: u32 align(16),
    r3: [6]u32 align(16),
    LVT_CMCI_reg: u32 align(16),
    int_cmd_reg: u32 align(16),
    LVT_timer: u32 align(16),
    LVT_termal_sensor: u32 align(16),
    LVT_perf_mon_ctrs: u32 align(16),
    LVT_lint0_reg: u32 align(16),
    LVT_lint1_reg: u32 align(16),
    LVT_err_reg: u32 align(16),
    inital_count_reg: u32 align(16),
    current_count_reg: u32 align(16),
    r4: [4]u32 align(16),
    timer_div_conf: u32 align(16),
};
const madt = @import("../ACPI/MADT.zig").MADT;
pub const APIC = struct {
    regs: *APICRegs,
    pub fn send_eoi() void {}
    pub fn init() ?void {
        madt.init() orelse return null;
    }
};
