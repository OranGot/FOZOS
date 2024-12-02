const limine = @import("limine");
const dfont = @import("fonts/dfont.zig");
const io = @import("std").io;
const fmt = @import("std").fmt;
const num = @import("../../util/num.zig");
const dbg = @import("../dbg/dbg.zig");
var framebuffer: *limine.Framebuffer = undefined;
const SPACES_PER_TAB: u16 = 4;
const FONT_CHARS_PER_LINE: u16 = 8;
const FONT_CHARS_PER_COL: u16 = 8;
pub var DEF_COLOR: u32 = 0xFFFFFFFF;
pub var DEF_BACK_COLOR: u32 = 0x0000;
var CWCOL: u64 = 0; //in pixels
var CWLINE: u64 = 0; // in pixels
var LINESIZE: u64 = 0;
var COLSIZE: u64 = 0;
const tty_writer = io.Writer(void, error{}, callback){ .context = {} };
fn callback(_: void, string: []const u8) error{}!usize {
    for (0..string.len) |n| {
        draw_char(string[n]);
    }
    return string.len;
}
pub fn initialise_tty(response: *limine.FramebufferResponse) void {
    framebuffer = response.framebuffers()[0];
    LINESIZE = framebuffer.width;
    COLSIZE = framebuffer.height;
}
fn draw_char(c: u8) void {
    if (c == 0) {
        return;
    } else if (c == '\t') {
        for (0..SPACES_PER_TAB) |_| {
            draw_char(' ');
        }
    } else if (c == '\n') {
        CWCOL = 0;
        CWLINE += FONT_CHARS_PER_COL;
        return;
    }
    // dbg.printf("framebuffer width: {}, height: {}, framebuffer addr: 0x{x}, pitch is: {}\n", .{
    //     framebuffer.width,
    //     framebuffer.height,
    //     @as(*u32, @ptrCast(@alignCast(framebuffer.address))),
    //     framebuffer.pitch,
    // });
    var d: u32 = 0;
    for (dfont.font8x8_basic[c]) |let| {
        for (0..8) |bit| {
            const x: u64 = d % FONT_CHARS_PER_LINE;
            const y: u64 = d / FONT_CHARS_PER_LINE;
            var clr = DEF_BACK_COLOR;
            //dbg.printf("getting bit {} from 0x{x}\n", .{ bit, let });
            if (num.get_bit_of_num(let, @truncate(bit)) == 1) {
                clr = DEF_COLOR;
            } else {
                d += 1;
                continue;
            }
            const pix_offset: u64 = (CWCOL + x) * 4 + (CWLINE + y) * framebuffer.pitch;
            // dbg.printf("Trying to write at: 0x{x} the color is: 0x{x}, pix offset: 0x{x}\ncwline: {}, cwcol: {}\n" ++
            //     "x: {}, y: {}\n", .{
            //     @as(*u32, @ptrCast(@alignCast(framebuffer.address + pix_offset))),
            //     clr,
            //     pix_offset,
            //     CWLINE,
            //     CWCOL,
            //     x,
            //     y,
            // });

            @as(*u32, @ptrCast(@alignCast(framebuffer.address + pix_offset))).* = clr;
            d += 1;
        }
    }
    // in this case start printing at the new line
    if (CWCOL > LINESIZE - FONT_CHARS_PER_LINE) {
        CWCOL = 0;
        CWLINE += FONT_CHARS_PER_COL;
    } else {
        CWCOL += FONT_CHARS_PER_LINE;
    }
}
pub fn printf(comptime format: []const u8, args: anytype) void {
    fmt.format(tty_writer, format, args) catch unreachable;
}
