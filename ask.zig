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
    const writer = std.io.getStdOut().writer();

    if (args.len > 1 and std.mem.eql(u8, args[1], "prompt")) {
        const content = try prompt.build(allocator, args[2..]);
        try writer.writeAll(content);
        std.process.exit(0);
    }

    const config = cli.parse(allocator, args[1..]);
    const content = try prompt.build(allocator, config.positional);
    const request = try api.buildRequest(allocator, config, content);
    var response = try api.makeRequest(allocator, request);
    var iterator = try streaming.Iterator.init(allocator, &response);

    while (try iterator.next()) |data| {
        _ = try writer.write(data);
    }

    try writer.writeAll("\n");
}
