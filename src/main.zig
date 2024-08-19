const std = @import("std");
const hasher = @import("hasher.zig");

pub fn main() void {
    const a = "Hello, world!";
    const ret = hasher.hash(a[0..], 0);
    std.debug.print("{x}", .{ret});
}
