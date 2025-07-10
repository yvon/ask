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
    var i: usize = 0;
    
    while (i < content.len) {
        if (std.mem.startsWith(u8, content[i..], "```")) {
            i += 3;
            
            while (i < content.len and content[i] != '\n') {
                i += 1;
            }
            
            if (i < content.len and content[i] == '\n') {
                i += 1;
            }
            
            const code_start = i;
            while (i < content.len - 2) {
                if (std.mem.startsWith(u8, content[i..], "```")) {
                    const code_content = content[code_start..i];
                    
                    if (code_content.len > 0) {
                        code_block_count += 1;
                        try createTempFile(allocator, code_content, code_block_count);
                    }
                    
                    i += 3;
                    break;
                }
                i += 1;
            }
        } else {
            i += 1;
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