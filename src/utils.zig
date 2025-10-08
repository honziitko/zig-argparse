///Strips optional.
///Not optinal = forced. Therefore, the process is enforcement
pub fn Enforce(T: type) type {
    switch (@typeInfo(T)) {
        .optional => |opt| return opt.child,
        else => return T,
    }
}

///Checks whether T is `fn (Args...) !Return`
pub fn checkFunctionConforms(T: type, Args: []const type, Return: type) bool {
    const info = switch (@typeInfo(T)) {
        .@"fn" => |i| i,
        else => return false,
    };
    if (info.is_var_args) return false;
    if (info.params.len != Args.len) return false;
    inline for (info.params, 0..) |param, i| {
        if (param.type.? != Args[i]) return false;
    }
    switch (@typeInfo(info.return_type.?)) {
        .error_union => |err_union| return err_union.payload == Return,
        else => false,
    }
}
