const std = @import("std");
const ArrayList = std.ArrayList;
const ChildProcess = std.process.Child;

pub const Manager = struct {
    allocator: std.mem.Allocator,
    processes: ArrayList(ChildProcess),

    pub fn init(allocator: std.mem.Allocator) Manager {
        return Manager{
            .allocator = allocator,
            .processes = ArrayList(ChildProcess).init(allocator),
        };
    }

    pub fn deinit(self: *Manager) void {
        for (self.processes.items) |*process| {
            _ = process.wait() catch {};
        }
        self.processes.deinit();
    }

    pub fn addProcess(self: *Manager, args: []const []const u8) !void {
        var process = ChildProcess.init(args, self.allocator);
        process.stdin_behavior = .Pipe;
        process.stdout_behavior = .Inherit;
        process.stderr_behavior = .Inherit;

        try process.spawn();
        try self.processes.append(process);
    }

    pub fn writeToAll(self: *Manager, data: []const u8) !void {
        for (self.processes.items) |*process| {
            if (process.stdin) |stdin| {
                _ = try stdin.writeAll(data);
            }
        }
    }

    pub fn closeAllStdin(self: *Manager) void {
        for (self.processes.items) |*process| {
            if (process.stdin) |stdin| {
                stdin.close();
                process.stdin = null;
            }
        }
    }
};
