const std = @import("std");
const cli = @import("cli.zig");
const prompt = @import("prompt.zig");
const api = @import("api.zig");
const streaming = @import("streaming.zig");
const pager = @import("pager.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const args = try std.process.argsAlloc(allocator);
    const config = cli.parse(allocator, args[1..]);

    if (config.positional.len > 0 and std.mem.eql(u8, config.positional[0], "prompt")) {
        const content = try prompt.build(allocator, config, config.positional[1..]);
        try std.io.getStdOut().writeAll(content);
        std.process.exit(0);
    }

    const content = try prompt.build(allocator, config, config.positional);
    const request = try api.buildRequest(allocator, config, content);
    var response = try api.makeRequest(allocator, request);
    var iterator = try streaming.Iterator.init(allocator, &response);
    var output = pager.Output.init(allocator);
    defer output.deinit();

    while (try iterator.next()) |data| {
        try output.file.writeAll(data);
    }

    try output.file.writeAll("\n");
}
