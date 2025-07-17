const std = @import("std");
const http = std.http;
const json = std.json;

pub const Event = struct {
    choices: []const struct {
        delta: ?struct {
            content: ?[]const u8,
        },
    },
};

pub const Iterator = struct {
    allocator: std.mem.Allocator,
    response_reader: http.Client.Request.Reader,
    line_buffer: []u8,
    finished: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, req: *http.Client.Request) !Self {
        const line_buffer = try allocator.alloc(u8, 4096);
        return Self{
            .allocator = allocator,
            .response_reader = req.reader(),
            .line_buffer = line_buffer,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.line_buffer);
    }

    pub fn next(self: *Self) !?[]const u8 {
        if (self.finished) return null;

        while (true) {
            const line = self.response_reader.readUntilDelimiterOrEof(self.line_buffer, '\n') catch |err| {
                if (err == error.EndOfStream) {
                    self.finished = true;
                    return null;
                }
                return err;
            };

            if (line) |l| {
                const trimmed = std.mem.trim(u8, l, " \t\r\n");
                if (trimmed.len == 0) continue;

                if (std.mem.startsWith(u8, trimmed, "data: ")) {
                    const data_json = trimmed[6..];

                    const parsed = json.parseFromSlice(Event, self.allocator, data_json, .{
                        .ignore_unknown_fields = true,
                    }) catch continue;

                    defer parsed.deinit();

                    if (parsed.value.choices.len > 0) {
                        if (parsed.value.choices[0].delta) |delta| {
                            if (delta.content) |content| {
                                const owned_content = try self.allocator.dupe(u8, content);
                                return owned_content;
                            }
                        }
                    }
                }
            } else {
                self.finished = true;
                return null;
            }
        }
    }
};
