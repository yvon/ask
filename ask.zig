const std = @import("std");
const config = @import("config.zig");
const api = @import("api.zig");
const streaming = @import("streaming.zig");
const parser = @import("parser.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const cfg = try config.parseArgs(allocator);
    const request = try api.buildRequest(allocator, cfg);
    var req = try api.makeRequest(allocator, cfg, request);
    defer req.deinit();

    const response = try streaming.processStreamingResponse(allocator, &req);
    defer allocator.free(response);
    
    try parser.parseMarkdownAndCreateTempFiles(allocator, response);
}
