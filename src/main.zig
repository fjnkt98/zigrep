const std = @import("std");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();

    try run(a, stdin, stdout);

    try bw.flush();
}

fn run(allocator: std.mem.Allocator, reader: anytype, writer: anytype) !void {
    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1073741824)) |line| {
        defer allocator.free(line);

        try std.fmt.format(writer, "line: {s}\n", .{line});
    }
}

test "input and output" {
    const allocator = std.testing.allocator;

    const buffer =
        \\foo
        \\bar baz
        \\qux
    ;
    var stream = std.io.FixedBufferStream([]const u8){ .buffer = std.mem.sliceTo(buffer, 0), .pos = 0 };
    const reader = stream.reader();

    var output = try std.ArrayList(u8).initCapacity(allocator, 1024);
    defer output.deinit();
    const writer = output.writer();

    try run(allocator, reader, writer);

    const expected =
        \\line: foo
        \\line: bar baz
        \\line: qux
        \\
    ;
    try std.testing.expectEqualStrings(expected, output.items);
}
