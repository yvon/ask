const std = @import("std");
const cli = @import("cli.zig");
const prompt = @import("prompt.zig");
const api = @import("api.zig");
const streaming = @import("streaming.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const args = try std.process.argsAlloc(allocator);

    if (args.len > 1 and std.mem.eql(u8, args[1], "prompt")) {
        const content = try prompt.build(allocator, args[2..]);
        try std.io.getStdOut().writer().writeAll(content);
        std.process.exit(0);
    }

    const config = cli.parse(allocator, args[1..]);
    const content = try prompt.build(allocator, config.positional);
    const request = try api.buildRequest(allocator, config, content);
    var response = try api.makeRequest(allocator, request);
    var iterator = try streaming.Iterator.init(allocator, &response);

    const pager = std.process.getEnvVarOwned(allocator, "PAGER") catch "less";

    var pager_args = std.ArrayList([]const u8).init(allocator);
    var token_iter = std.mem.tokenizeScalar(u8, pager, ' ');
    while (token_iter.next()) |token| {
        try pager_args.append(token);
    }
    var child = std.process.Child.init(pager_args.items, allocator);

    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    try child.spawn();
    const stdin = child.stdin.?;

    while (try iterator.next()) |data| {
        try stdin.writeAll(data);
    }

    try stdin.writeAll("\n");
    stdin.close();
    child.stdin = null;

    _ = try child.wait();
}
