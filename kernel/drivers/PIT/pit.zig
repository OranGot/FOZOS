const pio = @import("../drvlib/drvcmn.zig");
const CHANNEL_0_DPORT = 0x40;
const CHANNEL_1_DPORT = 0x41;
const CHANNEL_2_DPORT = 0x42;
const MODE_COMMAND_REG = 0x43;
const mc_reg = packed struct(u8) {
    b_mode: u1,
    op_mode: u3,
    access_mode: u2,
    channel: u2,
};
const dbg = @import("../dbg/dbg.zig");
pub fn unmask() void {
    pio.outb(MODE_COMMAND_REG, @bitCast(mc_reg{
        .channel = 0,
        .access_mode = 0,
        .b_mode = 0,
        .op_mode = 2,
    }));
}
