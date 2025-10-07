///Strips optional.
///Not optinal = forced. Therefore, the process is enforcement
pub fn Enforce(T: type) type {
    switch (@typeInfo(T)) {
        .optional => |opt| return opt.child,
        else => return T,
    }
}
