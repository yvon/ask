const std = @import("std");
const http = std.http;
const json = std.json;
const cli = @import("cli.zig");

pub const invalidConfigMessage =
    \\Error: invalid API configuration. Please set one of the following:
    \\  1. ANTHROPIC_API_KEY for Anthropic
    \\  2. OPENAI_API_KEY for OpenAI
    \\  3. OPENAI_BASE_URL, OPEN_AI_API_KEY, and ASK_MODEL for OpenAI compatible APIs
    \\
;

const Provider = struct {
    base_url: []const u8,
    api_key: []const u8,
    model: []const u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, cli_model: ?[]const u8) !Self {
        const model: ?[]const u8 = cli_model orelse
            std.process.getEnvVarOwned(allocator, "ASK_MODEL") catch null;

        if (std.process.getEnvVarOwned(allocator, "OPENAI_BASE_URL") catch null) |base_url| {
            const api_key = try std.process.getEnvVarOwned(allocator, "OPENAI_API_KEY");
            return Self{
                .base_url = base_url,
                .api_key = api_key,
                .model = model orelse return error.InvalidApiConfig,
                .allocator = allocator,
            };
        } else if (std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch null) |api_key| {
            return Self{
                .base_url = "https://api.anthropic.com/v1",
                .api_key = api_key,
                .model = model orelse "claude-sonnet-4-20250514",
                .allocator = allocator,
            };
        } else if (std.process.getEnvVarOwned(allocator, "OPENAI_API_KEY") catch null) |api_key| {
            return Self{
                .base_url = "https://api.openai.com/v1",
                .api_key = api_key,
                .model = model orelse "gpt-4.1-2025-04-14",
                .allocator = allocator,
            };
        }

        return error.InvalidApiConfig;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.base_url);
        self.allocator.free(self.api_key);
        self.allocator.free(self.model);
    }
};

pub const Message = struct {
    role: []const u8,
    content: []const u8,
};

pub const Body = struct {
    model: []const u8,
    max_output_tokens: u32,
    temperature: f32,
    messages: []const Message,
    stream: bool = true,
};

pub const Request = struct {
    provider: Provider,
    body: Body,
};

pub fn buildRequest(allocator: std.mem.Allocator, cfg: cli.Config, prompt: []const u8) !Request {
    const provider = try Provider.init(allocator, cfg.model);
    var messages = std.ArrayList(Message).init(allocator);

    if (cfg.system) |system_content| {
        try messages.append(Message{ .role = "system", .content = system_content });
    }

    try messages.append(Message{ .role = "user", .content = prompt });

    if (cfg.prefill) |prefill_content| {
        try messages.append(Message{ .role = "assistant", .content = prefill_content });
    }

    return Request{ .provider = provider, .body = Body{
        .model = provider.model,
        .max_output_tokens = cfg.max_tokens,
        .temperature = cfg.temperature,
        .messages = messages.items,
    } };
}

pub fn makeRequest(allocator: std.mem.Allocator, request: Request) !http.Client.Request {
    // Allocate reusable buffer
    const buffer = try allocator.alloc(u8, 1024 * 1024);

    // Serialize JSON to buffer without null optional fields
    var json_stream = std.io.fixedBufferStream(buffer);
    try json.stringify(request.body, .{ .emit_null_optional_fields = false }, json_stream.writer());
    const json_data = json_stream.getWritten();

    // Make HTTP request
    var client = http.Client{ .allocator = allocator };
    const uri_str = try std.fmt.allocPrint(allocator, "{s}/chat/completions", .{request.provider.base_url});
    defer allocator.free(uri_str);

    const uri = std.Uri.parse(uri_str) catch {
        std.debug.print("Error: invalid URI: {s}\n", .{uri_str});
        std.process.exit(1);
    };

    const auth_header = try std.fmt.allocPrint(allocator, "Bearer {s}", .{request.provider.api_key});

    var req = try client.open(.POST, uri, .{
        .server_header_buffer = try allocator.alloc(u8, 4096),
        .headers = .{
            .content_type = .{ .override = "application/json" },
            .authorization = .{ .override = auth_header },
        },
    });

    req.transfer_encoding = .{ .content_length = json_data.len };
    try req.send();
    try req.writeAll(json_data);
    try req.finish();
    try req.wait();

    if (req.response.status != http.Status.ok) {
        const len = try req.readAll(buffer);
        std.debug.print("%{s}\n", .{buffer[0..len]});
        std.process.exit(1);
    }

    return req;
}
