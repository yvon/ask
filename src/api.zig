const std = @import("std");
const http = std.http;
const json = std.json;
const cli = @import("cli.zig");

pub const Message = struct {
    role: []const u8,
    content: []const u8,
};

pub const Request = struct {
    model: []const u8,
    max_tokens: u32,
    temperature: f32,
    messages: []const Message,
    system: ?[]const u8 = null,
    stream: bool = true,
};

pub fn buildRequest(allocator: std.mem.Allocator, cfg: cli.Config, prompt: []const u8) !Request {
    var messages = std.ArrayList(Message).init(allocator);
    try messages.append(Message{ .role = "user", .content = prompt });

    if (cfg.prefill) |prefill_content| {
        try messages.append(Message{ .role = "assistant", .content = prefill_content });
    }

    return Request{
        .max_tokens = cfg.max_tokens,
        .temperature = cfg.temperature,
        .messages = messages.items,
        .system = cfg.system,
        .model = cfg.model,
        .stream = true,
    };
}

pub fn makeRequest(allocator: std.mem.Allocator, request: Request) !http.Client.Request {
    // Allocate reusable buffer
    const buffer = try allocator.alloc(u8, 1024 * 1024);

    // Serialize JSON to buffer without null optional fields
    var json_stream = std.io.fixedBufferStream(buffer);
    try json.stringify(request, .{ .emit_null_optional_fields = false }, json_stream.writer());
    const json_data = json_stream.getWritten();

    // Make HTTP request
    var client = http.Client{ .allocator = allocator };
    const uri = try std.Uri.parse("https://api.anthropic.com/v1/messages");
    const api_key = apiKey(allocator);
    const auth_header = try std.fmt.allocPrint(allocator, "Bearer {s}", .{api_key});

    var req = try client.open(.POST, uri, .{
        .server_header_buffer = try allocator.alloc(u8, 4096),
        .headers = .{
            .content_type = .{ .override = "application/json" },
            .authorization = .{ .override = auth_header },
        },
        .extra_headers = &.{
            .{ .name = "anthropic-version", .value = "2023-06-01" },
            .{ .name = "x-api-key", .value = api_key },
        },
    });

    req.transfer_encoding = .{ .content_length = json_data.len };
    try req.send();
    try req.writeAll(json_data);
    try req.finish();
    try req.wait();

    return req;
}

fn apiKey(allocator: std.mem.Allocator) []const u8 {
    return std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch |err| {
        std.debug.print("Error: ANTHROPIC_API_KEY not found: {any}\n", .{err});
        std.debug.print("Please set your Anthropic API key as an environment variable.\n", .{});
        std.process.exit(1);
    };
}
