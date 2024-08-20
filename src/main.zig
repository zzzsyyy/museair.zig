const print = @import("std").debug.print;
const hasher = @import("hasher.zig");

pub fn main() !void {
    const input = "Hello, world!";
    const hash = hasher.hash(input[0..], 0);
    const hash128 = hasher.hash_128(input[0..], 0);

    print("str: {s}\n", .{input});
    print("hash: {x}\n", .{hash});
    print("hash128: {x}\n", .{hash128});
}
