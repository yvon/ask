const std = @import("std");
const cli = @import("cli.zig");
const prompt = @import("prompt.zig");
const api = @import("api.zig");
const streaming = @import("streaming.zig");
const PipeManager = @import("pipe_manager.zig").PipeManager;

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

    // Request LLM
    const request = try api.buildRequest(allocator, config, content);
    var response = try api.makeRequest(allocator, request);
    var iterator = try streaming.Iterator.init(allocator, &response);

    // Spawn child processes (pager, git apply)
    var pipe_manager = PipeManager.init(allocator);
    defer pipe_manager.deinit();
    defer pipe_manager.closeAllStdin();
    try pipe_manager.addProcess(try pager_args(allocator));
    if (config.apply) {
        try pipe_manager.addProcess(&.{ "git", "apply", "-" });
    }

    // Write output
    if (config.prefill) |prefill| {
        try pipe_manager.writeToAll(prefill);
    }
    while (try iterator.next()) |data| {
        try pipe_manager.writeToAll(data);
    }
    try pipe_manager.writeToAll("\n");
}

fn pager_args(allocator: std.mem.Allocator) ![]const []const u8 {
    const pager = std.process.getEnvVarOwned(allocator, "PAGER") catch "less";

    var args = std.ArrayList([]const u8).init(allocator);

    var token_iter = std.mem.tokenizeScalar(u8, pager, ' ');
    while (token_iter.next()) |token| {
        try args.append(token);
    }

    return args.toOwnedSlice();
}
