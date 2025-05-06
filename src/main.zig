const std = @import("std");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stderr = std.io.getStdErr().writer();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const args = try getArgs(allocator);
    const option = parseArgs(allocator, args.items) catch |err| {
        try stderr.print("Error: {any}\n", .{err});
        std.posix.exit(1);
    };

    try run(allocator, stdin, stdout, option);
}

fn getArgs(allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var itr = try std.process.argsWithAllocator(allocator);
    defer itr.deinit();

    var args = std.ArrayList([]const u8).init(allocator);

    while (itr.next()) |arg| {
        try args.append(arg);
    }

    return args;
}

const Option = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    pattern: []const u8,

    pub fn init(allocator: std.mem.Allocator, pattern: []const u8) Self {
        return Option{ .allocator = allocator, .pattern = pattern };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.pattern);
    }
};

const PatternNotFound = error{};
const EmptyPattern = error{};

fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !Option {
    if (args.len < 2) {
        return error.PatternNotFound;
    }

    const data = args[1];
    if (data.len == 0) {
        return error.EmptyPattern;
    }

    const pattern = try allocator.alloc(u8, data.len);
    @memcpy(pattern, data);

    return Option.init(allocator, pattern);
}

fn run(allocator: std.mem.Allocator, reader: anytype, writer: anytype, option: Option) !void {
    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1073741824)) |line| {
        defer allocator.free(line);

        if (std.mem.containsAtLeast(u8, line, 1, option.pattern)) {
            try std.fmt.format(writer, "{s}\n", .{line});
        }
    }
}

test "parse args" {
    const allocator = std.testing.allocator;

    const args = [_][]const u8{
        "/path/to/executable",
        "zigrep",
        "foo",
        "bar",
    };

    const option = try parseArgs(allocator, &args);
    defer option.deinit();
    try std.testing.expectEqualStrings("zigrep", option.pattern);
}

test "no pattern specified" {
    const allocator = std.testing.allocator;

    const args = [_][]const u8{
        "/path/to/executable",
    };

    try std.testing.expectEqual(error.PatternNotFound, parseArgs(allocator, &args));
}

test "empty pattern" {
    const allocator = std.testing.allocator;

    const args = [_][]const u8{
        "/path/to/executable",
        "",
    };

    try std.testing.expectEqual(error.EmptyPattern, parseArgs(allocator, &args));
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

    const option = Option.init(allocator, "foo");

    try run(allocator, reader, writer, option);

    const expected =
        \\foo
        \\
    ;
    try std.testing.expectEqualStrings(expected, output.items);
}
