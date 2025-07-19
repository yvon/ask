const std = @import("std");
const cli = @import("cli.zig");

fn readStdin(allocator: std.mem.Allocator, writer: anytype) !void {
    const stdin = std.io.getStdIn().reader();
    const content = try stdin.readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);
    try writer.writeAll(content);
}

pub fn build(allocator: std.mem.Allocator, config: cli.Config) ![]const u8 {
    const args = config.positional;
    var prompt = std.ArrayList(u8).init(allocator);
    const writer = prompt.writer();

    const is_tty = std.io.getStdIn().isTty();

    if (!is_tty) {
        try readStdin(allocator, writer);
    }

    if (args.len > 0) {
        const sentence = try std.mem.join(allocator, " ", args);
        try prompt.appendSlice(sentence);
    }

    return prompt.items;
}
