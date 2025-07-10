const std = @import("std");
const json = std.json;
const http = std.http;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);

    var max_tokens: u32 = 5000;
    var temperature: f32 = 0.0;
    var prefill: ?[]const u8 = null;
    var system: ?[]const u8 = null;
    var model: []const u8 = "claude-sonnet-4-20250514";
    var prompt_args = std.ArrayList([]const u8).init(allocator);

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
        } else {
            // This is a prompt argument
            try prompt_args.append(args[i]);
        }
    }

    // Read from stdin first
    const stdin = std.io.getStdIn().reader();
    const stdin_content = stdin.readAllAlloc(allocator, 1024 * 1024) catch "";

    // Build prompt starting with stdin content
    var prompt_builder = std.ArrayList(u8).init(allocator);
    
    // Add stdin content first
    if (stdin_content.len > 0) {
        try prompt_builder.appendSlice(stdin_content);
    }

    // Then append prompt arguments
    for (prompt_args.items, 0..) |arg, idx| {
        if (prompt_builder.items.len > 0 or idx > 0) {
            try prompt_builder.append(' ');
        }
        try prompt_builder.appendSlice(arg);
    }

    const final_prompt = prompt_builder.items;

    if (final_prompt.len == 0) {
        std.debug.print("No prompt provided via arguments or stdin\n", .{});
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
        stream: bool = true,
    };

    // Build messages array
    var messages = std.ArrayList(Message).init(allocator);
    try messages.append(Message{ .role = "user", .content = final_prompt });

    if (prefill) |prefill_content| {
        try messages.append(Message{ .role = "assistant", .content = prefill_content });
    }

    const request = Request{
        .max_tokens = max_tokens,
        .temperature = temperature,
        .messages = messages.items,
        .system = system,
        .model = model,
        .stream = true,
    };

    // Allocate reusable buffer
    const buffer = try allocator.alloc(u8, 1024 * 1024);

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

    // Process streaming response
    var response_reader = req.reader();
    const line_buffer = try allocator.alloc(u8, 4096);

    while (true) {
        const line = response_reader.readUntilDelimiterOrEof(line_buffer, '\n') catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        if (line) |l| {
            const trimmed = std.mem.trim(u8, l, " \t\r\n");
            if (trimmed.len == 0) continue;

            // Parse SSE format
            if (std.mem.startsWith(u8, trimmed, "data: ")) {
                const data_json = trimmed[6..];

                // Parse the JSON event
                const Event = struct {
                    type: []const u8,
                    delta: ?struct {
                        type: []const u8,
                        text: ?[]const u8 = null,
                    } = null,
                };

                const parsed = json.parseFromSlice(Event, allocator, data_json, .{
                    .ignore_unknown_fields = true,
                }) catch {
                    // Skip unparseable events
                    continue;
                };

                // Handle content_block_delta events with text
                if (std.mem.eql(u8, parsed.value.type, "content_block_delta")) {
                    if (parsed.value.delta) |delta| {
                        if (std.mem.eql(u8, delta.type, "text_delta")) {
                            if (delta.text) |text| {
                                try std.io.getStdOut().writer().print("{s}", .{text});
                            }
                        }
                    }
                }

                // Handle message_stop event
                if (std.mem.eql(u8, parsed.value.type, "message_stop")) {
                    break;
                }
            }
        } else {
            break;
        }
    }

    // Print final newline
    try std.io.getStdOut().writer().print("\n", .{});
}
