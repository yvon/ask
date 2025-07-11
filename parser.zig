const std = @import("std");
const temp = @import("temp.zig");

pub fn parseMarkdownAndCreateTempFiles(allocator: std.mem.Allocator, content: []const u8) !void {
    var lines = std.mem.splitScalar(u8, content, '\n');
    var in_diff_block = false;
    var diff_lines = std.ArrayList([]const u8).init(allocator);

    // Create file for whole response
    try createWholeResponseFile(allocator, content);

    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "```diff")) {
            in_diff_block = true;
            diff_lines.clearRetainingCapacity();
        } else if (in_diff_block and std.mem.startsWith(u8, line, "```")) {
            in_diff_block = false;

            if (diff_lines.items.len > 0) {
                const diff_content = try std.mem.join(allocator, "\n", diff_lines.items);
                try applyDiffPatch(diff_content);
            }
        } else if (in_diff_block) {
            try diff_lines.append(line);
        }
    }
}

fn applyDiffPatch(diff_content: []const u8) !void {
    var process = std.process.Child.init(&[_][]const u8{"patch"}, std.heap.page_allocator);
    process.stdin_behavior = .Pipe;

    try process.spawn();

    if (process.stdin) |stdin| {
        try stdin.writeAll(diff_content);
        try stdin.writeAll("\n");
        stdin.close();
        process.stdin = null;
    }

    const result = try process.wait();

    switch (result) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("patch command failed with exit code: {}\n", .{code});
            }
        },
        else => {
            std.debug.print("patch command failed\n", .{});
        },
    }
}

fn createWholeResponseFile(allocator: std.mem.Allocator, content: []const u8) !void {
    const filename = "ask.response";
    try temp.writeTempFile(allocator, content, filename);
}
