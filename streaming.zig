const std = @import("std");
const http = std.http;
const json = std.json;

pub const Event = struct {
    type: []const u8,
    delta: ?struct {
        type: []const u8,
        text: ?[]const u8 = null,
    } = null,
};

pub fn processStreamingResponse(allocator: std.mem.Allocator, req: *http.Client.Request) !void {
    var response_reader = req.reader();
    const line_buffer = try allocator.alloc(u8, 4096);
    var full_response = std.ArrayList(u8).init(allocator);
    defer full_response.deinit();

    while (true) {
        const line = response_reader.readUntilDelimiterOrEof(line_buffer, '\n') catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        if (line) |l| {
            const trimmed = std.mem.trim(u8, l, " \t\r\n");
            if (trimmed.len == 0) continue;

            if (std.mem.startsWith(u8, trimmed, "data: ")) {
                const data_json = trimmed[6..];

                const parsed = json.parseFromSlice(Event, allocator, data_json, .{
                    .ignore_unknown_fields = true,
                }) catch {
                    continue;
                };

                if (std.mem.eql(u8, parsed.value.type, "content_block_delta")) {
                    if (parsed.value.delta) |delta| {
                        if (std.mem.eql(u8, delta.type, "text_delta")) {
                            if (delta.text) |text| {
                                try std.io.getStdOut().writer().print("{s}", .{text});
                                try full_response.appendSlice(text);
                            }
                        }
                    }
                }

                if (std.mem.eql(u8, parsed.value.type, "message_stop")) {
                    break;
                }
            }
        } else {
            break;
        }
    }

    try std.io.getStdOut().writer().print("\n", .{});

    try parseMarkdownAndCreateTempFiles(allocator, full_response.items);
}

fn parseMarkdownAndCreateTempFiles(allocator: std.mem.Allocator, content: []const u8) !void {
    var code_block_count: u32 = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var in_code_block = false;
    var code_lines = std.ArrayList([]const u8).init(allocator);
    defer code_lines.deinit();

    while (lines.next()) |line| {
        const trimmed_line = std.mem.trim(u8, line, " \t\r");

        if (std.mem.startsWith(u8, trimmed_line, "```")) {
            if (!in_code_block) {
                in_code_block = true;
                code_lines.clearRetainingCapacity();
            } else {
                in_code_block = false;

                if (code_lines.items.len > 0) {
                    code_block_count += 1;

                    var code_content = std.ArrayList(u8).init(allocator);
                    defer code_content.deinit();

                    for (code_lines.items, 0..) |code_line, idx| {
                        try code_content.appendSlice(code_line);
                        if (idx < code_lines.items.len - 1) {
                            try code_content.append('\n');
                        }
                    }

                    try createTempFile(allocator, code_content.items, code_block_count);
                }
            }
        } else if (in_code_block) {
            try code_lines.append(line);
        }
    }
}

fn createTempFile(allocator: std.mem.Allocator, content: []const u8, count: u32) !void {
    const filename = try std.fmt.allocPrint(allocator, "/tmp/ask.code.{d}", .{count});
    defer allocator.free(filename);

    const file = std.fs.createFileAbsolute(filename, .{}) catch |err| {
        std.debug.print("Failed to create temp file {s}: {}\n", .{ filename, err });
        return;
    };
    defer file.close();

    file.writeAll(content) catch |err| {
        std.debug.print("Failed to write to temp file {s}: {}\n", .{ filename, err });
        return;
    };

    std.debug.print("Created temp file: {s}\n", .{filename});
}