pub fn rdmsr(index: u32) u64 {
    var low: u32 = 0;
    var high: u32 = 0;
    asm volatile ("rdmsr"
        : [lo] "={rax}" (low),
          [hi] "={rdx}" (high),
        : [ind] "{rcx}" (index),
    );
    return (@as(u64, @intCast(high)) << 32) | @as(u64, @intCast(low));
}

pub fn wrmsr(index: u32, val: u64) void {
    const low: u32 = @as(u32, @intCast(val & 0xFFFFFFFF));
    const high: u32 = @as(u32, @intCast(val >> 32));
    asm volatile ("wrmsr"
        :
        : [lo] "{rax}" (low),
          [hi] "{rdx}" (high),
          [ind] "{rcx}" (index),
    );
}

