const std = @import("std");
const builtin = @import("builtin");

pub fn getTempDir(allocator: std.mem.Allocator) ![]u8 {
    // Try to get TMPDIR environment variable in a cross-platform way
    if (std.process.getEnvVarOwned(allocator, "TMPDIR")) |tmpdir| {
        return tmpdir;
    } else |err| switch (err) {
        error.EnvironmentVariableNotFound => {
            // Try other common temp directory environment variables
            const temp_vars = [_][]const u8{ "TEMP", "TMP" };
            for (temp_vars) |var_name| {
                if (std.process.getEnvVarOwned(allocator, var_name)) |tmpdir| {
                    return tmpdir;
                } else |_| {
                    continue;
                }
            }

            // Platform-specific fallbacks
            const default_temp = switch (builtin.os.tag) {
                .windows => "C:\\temp",
                else => "/tmp",
            };
            return try allocator.dupe(u8, default_temp);
        },
        else => return err,
    }
}

pub fn writeTempFile(allocator: std.mem.Allocator, content: []const u8, filename: []const u8) !void {
    const tmp_dir_path = try getTempDir(allocator);

    const full_path = try std.fs.path.join(allocator, &[_][]const u8{ tmp_dir_path, filename });

    const file = std.fs.createFileAbsolute(full_path, .{}) catch |err| {
        std.debug.print("Failed to create temp file {s}: {}\n", .{ full_path, err });
        return;
    };

    defer file.close();

    file.writeAll(content) catch |err| {
        std.debug.print("Failed to write to temp file {s}: {}\n", .{ full_path, err });
        return;
    };
}