const std = @import("std");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();
    try run(a, stdin);
}

fn run(allocator: std.mem.Allocator, input: anytype) !void {
    while (try input.readUntilDelimiterOrEofAlloc(allocator, '\n', 1073741824)) |line| {
        defer allocator.free(line);

        std.debug.print("line: {s}\n", .{line});
    }
}
