const hasher = @import("hasher.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len < 2) {
        try stdout.writeAll("expected input argument\n");
        return;
    }

    const input = args[1];
    const output = hasher.hash(input, 0);
    try stdout.print("{x}\n", .{output});
}
