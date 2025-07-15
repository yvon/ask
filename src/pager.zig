const std = @import("std");

pub const Output = struct {
    allocator: std.mem.Allocator,
    child: ?std.process.Child,
    file: std.fs.File,

    const Self = @This();

    // Try to spawn pager, fallback to stdout
    pub fn init(allocator: std.mem.Allocator) Self {
        if (spawnPager(allocator)) |child| {
            const stdin = child.stdin.?;
            return Self{
                .allocator = allocator,
                .child = child,
                .file = stdin,
            };
        } else |_| {
            return Self{
                .allocator = allocator,
                .child = null,
                .file = std.io.getStdOut(),
            };
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.child) |*child| {
            if (child.stdin) |stdin| {
                stdin.close();
                child.stdin = null;
            }
            _ = child.wait() catch {};
        }
    }

    fn spawnPager(allocator: std.mem.Allocator) !std.process.Child {
        const pager = std.process.getEnvVarOwned(allocator, "PAGER") catch "less";

        var pager_args = std.ArrayList([]const u8).init(allocator);
        defer pager_args.deinit();

        var token_iter = std.mem.tokenizeScalar(u8, pager, ' ');
        while (token_iter.next()) |token| {
            try pager_args.append(token);
        }

        var child = std.process.Child.init(pager_args.items, allocator);
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        try child.spawn();
        return child;
    }
};
