const std = @import("std");
const json = std.json;
const http = std.http;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);

    var max_tokens: u32 = 1024;
    var temperature: f32 = 0.0;
    var prefill: ?[]const u8 = null;
    var system: ?[]const u8 = null;
    var model: []const u8 = "claude-sonnet-4-20250514";

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--max-tokens") and i + 1 < args.len) {
            max_tokens = std.fmt.parseInt(u32, args[i + 1], 10) catch {
                std.debug.print("Invalid max-tokens value: {s}\n", .{args[i + 1]});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--temperature") and i + 1 < args.len) {
            temperature = std.fmt.parseFloat(f32, args[i + 1]) catch {
                std.debug.print("Invalid temperature value: {s}\n", .{args[i + 1]});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--prefill") and i + 1 < args.len) {
            prefill = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--system") and i + 1 < args.len) {
            system = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--model") and i + 1 < args.len) {
            model = args[i + 1];
            i += 1;
        }
    }

    // Read prompt from stdin
    const stdin = std.io.getStdIn().reader();
    const prompt = try stdin.readAllAlloc(allocator, 1024 * 1024);

    if (prompt.len == 0) {
        std.process.exit(1);
    }

    // Create JSON request structure
    const Message = struct {
        role: []const u8,
        content: []const u8,
    };

    const Request = struct {
        model: []const u8,
        max_tokens: u32,
        temperature: f32,
        messages: []const Message,
        system: ?[]const u8 = null,
    };

    // Build messages array
    var messages = std.ArrayList(Message).init(allocator);
    try messages.append(Message{ .role = "user", .content = prompt });

    if (prefill) |prefill_content| {
        try messages.append(Message{ .role = "assistant", .content = prefill_content });
    }

    const request = Request{
        .max_tokens = max_tokens,
        .temperature = temperature,
        .messages = messages.items,
        .system = system,
        .model = model,
    };

    // Allocate reusable buffer
    var buffer = try allocator.alloc(u8, 1024 * 1024);

    // Serialize JSON to buffer without null optional fields
    var json_stream = std.io.fixedBufferStream(buffer);
    try json.stringify(request, .{ .emit_null_optional_fields = false }, json_stream.writer());
    const json_data = json_stream.getWritten();

    // Get API key from environment
    const api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch |err| {
        std.debug.print("ANTHROPIC_API_KEY not found: {}\n", .{err});
        std.process.exit(1);
    };

    // Make HTTP request
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse("https://api.anthropic.com/v1/messages");

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
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = json_data.len };
    try req.send();
    try req.writeAll(json_data);
    try req.finish();
    try req.wait();

    // Reuse same buffer for response
    const bytes_read = try req.readAll(buffer);
    const response_body = buffer[0..bytes_read];

    // Parse JSON response with ignore_unknown_fields
    const Response = struct {
        content: []const struct {
            text: []const u8,
        },
    };

    const parsed = json.parseFromSlice(Response, allocator, response_body, .{
        .ignore_unknown_fields = true,
    }) catch |err| {
        std.debug.print("Error parsing JSON: {}\n", .{err});
        std.debug.print("Response body: {s}\n", .{response_body});
        std.process.exit(1);
    };

    if (parsed.value.content.len > 0) {
        std.debug.print("{s}\n", .{parsed.value.content[0].text});
    }
}