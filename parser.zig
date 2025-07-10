const std = @import("std");
const temp = @import("tmp_dir.zig");

pub fn parseMarkdownAndCreateTempFiles(allocator: std.mem.Allocator, content: []const u8) !void {
    var code_block_count: u32 = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var in_code_block = false;
    var code_lines = std.ArrayList([]const u8).init(allocator);
    defer code_lines.deinit();

    // Create file for whole response
    try createWholeResponseFile(allocator, content);

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
    const filename = try std.fmt.allocPrint(allocator, "ask.code.{d}", .{count});
    defer allocator.free(filename);

    const tmp_dir_path = try temp.getTempDir(allocator);
    defer allocator.free(tmp_dir_path);

    const full_path = try std.fs.path.join(allocator, &[_][]const u8{ tmp_dir_path, filename });
    defer allocator.free(full_path);

    const file = std.fs.createFileAbsolute(full_path, .{}) catch |err| {
        std.debug.print("Failed to create temp file {s}: {}\n", .{ full_path, err });
        return;
    };
    defer file.close();

    file.writeAll(content) catch |err| {
        std.debug.print("Failed to write to temp file {s}: {}\n", .{ full_path, err });
        return;
    };

    std.debug.print("Extracted code: {s}\n", .{full_path});
}

fn createWholeResponseFile(allocator: std.mem.Allocator, content: []const u8) !void {
    const filename = "ask.response";

    const tmp_dir_path = try temp.getTempDir(allocator);
    defer allocator.free(tmp_dir_path);

    const full_path = try std.fs.path.join(allocator, &[_][]const u8{ tmp_dir_path, filename });
    defer allocator.free(full_path);

    const file = std.fs.createFileAbsolute(full_path, .{}) catch |err| {
        std.debug.print("Failed to create response file {s}: {}\n", .{ full_path, err });
        return;
    };
    defer file.close();

    file.writeAll(content) catch |err| {
        std.debug.print("Failed to write to response file {s}: {}\n", .{ full_path, err });
        return;
    };

    std.debug.print("---\nClaude's response saved in file: {s}\n", .{full_path});
}