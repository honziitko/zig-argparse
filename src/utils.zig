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
        else => return false,
    }
}

const testing = @import("std").testing;
test "Enforce" {
    try testing.expectEqual(i32, Enforce(i32));
    try testing.expectEqual(i32, Enforce(?i32));
    const E = error{};
    try testing.expectEqual(E!i32, Enforce(E!i32));
}

test "checkFunctionConforms" {
    const E = error{ A, B, C };
    try testing.expect(checkFunctionConforms(fn (i32) E!i32, &[_]type{i32}, i32));
    try testing.expect(!checkFunctionConforms(fn (u8) E!i32, &[_]type{i32}, i32));
    try testing.expect(!checkFunctionConforms(fn (i32) E!u8, &[_]type{i32}, i32));
    try testing.expect(!checkFunctionConforms(fn (u8) E!u32, &[_]type{i32}, i32));
    try testing.expect(!checkFunctionConforms(fn (i32, i32) E!i32, &[_]type{i32}, i32));
    try testing.expect(!checkFunctionConforms(fn (i32) i32, &[_]type{i32}, i32));
}
