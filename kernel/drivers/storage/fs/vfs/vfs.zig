pub const VFS = struct {
    
    pub fn mount()

};
pub const MountPoint = struct {
    path: []const u8,
    did: u16,
    drvid: u16,
    b_addr: u64,
    h_addr: u64,
};
