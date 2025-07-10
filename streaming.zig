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

pub fn processStreamingResponse(allocator: std.mem.Allocator, req: *http.Client.Request) ![]u8 {
    var response_reader = req.reader();
    const line_buffer = try allocator.alloc(u8, 4096);
    var full_response = std.ArrayList(u8).init(allocator);

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

    return full_response.toOwnedSlice();
}

