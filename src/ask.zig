const std = @import("std");
const cli = @import("cli.zig");
const prompt = @import("prompt.zig");
const api = @import("api.zig");
const streaming = @import("streaming.zig");

const Output = struct {
    content: std.ArrayList(u8),
    pager: std.process.Child,

    pub fn init(allocator: std.mem.Allocator) !Output {
        return Output{
            .content = std.ArrayList(u8).init(allocator),
            .pager = try spawnPager(allocator),
        };
    }

    pub fn deinit(self: *Output) void {
        self.content.deinit();
    }

    pub fn append(self: *Output, data: []const u8) !void {
        try self.content.appendSlice(data);
        try self.pager.stdin.?.writeAll(data);
    }

    pub fn close(self: *Output) !void {
        try closeAndWait(&self.pager);
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    const config = cli.parse(allocator, args[1..]);

    // Build the prompt
    const content = try prompt.build(allocator, config);

    if (config.debug_prompt) {
        try std.io.getStdOut().writeAll(content);
        std.process.exit(0);
    }

    const request = api.buildRequest(allocator, config, content) catch {
        std.debug.print(api.invalidConfigMessage, .{});
        std.process.exit(1);
    };

    var output = try Output.init(allocator);
    defer output.deinit();

    // Request LLM
    var response = try api.makeRequest(allocator, request);
    var stream = try streaming.Iterator.init(allocator, &response);

    // Compare the initial data with the prefill. Prepend it if required.
    if (config.prefill) |prefill| {
        if (try stream.next()) |data| {
            if (!std.mem.startsWith(u8, data, prefill)) {
                try output.append(prefill);
            }
            try output.append(data);
        }
    }

    // No specific format expected, just output the data and exit
    if (!config.diff) {
        while (try stream.next()) |data| {
            try output.append(data);
        }
        try output.append("\n");
        try output.close();

        std.process.exit(0);
    }

    // Here comes the fun part: cleanup generated diffs
    var buffer = try std.ArrayList(u8).initCapacity(allocator, 4048);

    outer: while (try stream.next()) |data| {
        var it = std.mem.splitScalar(u8, data, '\n');
        while (it.next()) |line| {
            try buffer.appendSlice(line);

            if (it.peek() != null) {
                try buffer.append('\n');

                if (buffer.items[0] != '+' and
                    buffer.items[0] != '-' and
                    buffer.items[0] != ' ' and
                    !std.mem.startsWith(u8, buffer.items, "diff") and
                    !std.mem.startsWith(u8, buffer.items, "index") and
                    !std.mem.startsWith(u8, buffer.items, "---") and
                    !std.mem.startsWith(u8, buffer.items, "+++") and
                    !std.mem.startsWith(u8, buffer.items, "@@"))
                {
                    break :outer;
                }

                try output.append(buffer.items);
                buffer.clearRetainingCapacity();
            }
        }
    }

    try output.close();

    // Apply the generated diff
    if (config.apply) {
        var git_apply = try spanGitApply(allocator);
        try git_apply.stdin.?.writeAll(output.content.items);
        try closeAndWait(&git_apply);
    }
}

fn pagerArgs(allocator: std.mem.Allocator) ![]const []const u8 {
    const pager = std.process.getEnvVarOwned(allocator, "PAGER") catch "less -XE";

    var args = std.ArrayList([]const u8).init(allocator);

    var token_iter = std.mem.tokenizeScalar(u8, pager, ' ');
    while (token_iter.next()) |token| {
        try args.append(token);
    }

    return args.toOwnedSlice();
}

fn spawnPager(allocator: std.mem.Allocator) !std.process.Child {
    const argv = try pagerArgs(allocator);
    return spawnProcess(allocator, argv);
}

fn spanGitApply(allocator: std.mem.Allocator) !std.process.Child {
    const argv = &.{ "git", "apply", "--reject", "--recount", "-" };
    return spawnProcess(allocator, argv);
}

fn closeAndWait(process: *std.process.Child) !void {
    process.stdin.?.close();
    process.stdin = null; // or else wait() will try to close it too
    _ = try process.wait();
}

fn spawnProcess(allocator: std.mem.Allocator, args: []const []const u8) !std.process.Child {
    var process = std.process.Child.init(args, allocator);
    process.stdin_behavior = .Pipe;

    try process.spawn();
    return process;
}
