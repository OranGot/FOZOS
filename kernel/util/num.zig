pub fn get_bit_of_num(num: u64, bit: u8) u1 {
    return @truncate((num >> @truncate(bit)) % 2);
}
pub fn set_bit_of_num(num: u64, bit: u8, state: u1) u64 {
    return num | (state << bit);
}
