const std = @import("std");
const config = @import("config.zig");
const prompt = @import("prompt.zig");
const api = @import("api.zig");
const streaming = @import("streaming.zig");
const parser = @import("parser.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const parsed_args = try config.parseArgs(allocator);
    const built_prompt = try prompt.buildPrompt(allocator, parsed_args);
    const cfg = prompt.createConfig(parsed_args, built_prompt);
    const request = try api.buildRequest(allocator, cfg);
    var req = try api.makeRequest(allocator, cfg, request);
    const response = try streaming.processStreamingResponse(allocator, &req);
    try parser.parseMarkdownAndCreateTempFiles(allocator, response);
}