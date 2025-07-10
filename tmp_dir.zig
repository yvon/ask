const std = @import("std");

pub fn getTempDir(allocator: std.mem.Allocator) ![]u8 {
    if (std.posix.getenv("TMPDIR")) |tmpdir| {
        return try allocator.dupe(u8, tmpdir);
    }

    // Default fallback
    return try allocator.dupe(u8, "/tmp");
}