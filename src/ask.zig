const std = @import("std");
const cli = @import("cli.zig");
const prompt = @import("prompt.zig");
const api = @import("api.zig");
const streaming = @import("streaming.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    const config = cli.parse(allocator, args[1..]);

    // Build the prompt
    const content = try prompt.build(allocator, config);

    if (config.debug_prompt) {
        try std.io.getStdOut().writeAll(content);
        std.process.exit(0);
    }

    const request = api.buildRequest(allocator, config, content) catch {
        std.debug.print(api.invalidConfigMessage, .{});
        std.process.exit(1);
    };

    // Request LLM
    var response = try api.makeRequest(allocator, request);
    var stream = try streaming.Iterator.init(allocator, &response);

    // Output
    if (config.prefill) |prefill| {
        try std.io.getStdOut().writeAll(prefill);
    }

    while (try stream.next()) |data| {
        try std.io.getStdOut().writeAll(data);
    }

    try std.io.getStdOut().writeAll("\n");
}
