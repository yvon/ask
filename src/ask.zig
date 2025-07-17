const std = @import("std");
const cli = @import("cli.zig");
const prompt = @import("prompt.zig");
const api = @import("api.zig");
const streaming = @import("streaming.zig");

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

    var pager = try spawnPager(allocator);

    // Request LLM
    var output = std.ArrayList(u8).init(allocator);
    var response = try api.makeRequest(allocator, request);
    var iterator = try streaming.Iterator.init(allocator, &response);

    // Output
    if (config.prefill) |prefill| {
        try pager.stdin.?.writeAll(prefill);
        try output.appendSlice(prefill);
    }
    while (try iterator.next()) |data| {
        try pager.stdin.?.writeAll(data);
        try output.appendSlice(data);
    }
    try pager.stdin.?.writeAll("\n");

    try closeAndWait(&pager);

    if (!config.apply) {
        return;
    }

    { // git apply --reject --recount --unidiff-zero --inaccurate-eof -
        var git_apply = try spanGitApply(allocator);

        // line by line to filter out garbage
        var in_diff = false;
        var lines = std.mem.splitScalar(u8, output.items, '\n');
        while (lines.next()) |line| {
            if (in_diff) {
                // the LLM added content after the diff: break
                if (line.len < 1) break;
                if (line[0] != '+' and line[0] != '-' and line[0] != ' ') break;
            }
            try git_apply.stdin.?.writeAll(line);
            try git_apply.stdin.?.writeAll("\n");
            // diff starts after @@ line
            if (std.mem.startsWith(u8, line, "@@")) in_diff = true;
        }

        try closeAndWait(&git_apply);
    }
}

fn pager_args(allocator: std.mem.Allocator) ![]const []const u8 {
    const pager = std.process.getEnvVarOwned(allocator, "PAGER") catch "less -XE";

    var args = std.ArrayList([]const u8).init(allocator);

    var token_iter = std.mem.tokenizeScalar(u8, pager, ' ');
    while (token_iter.next()) |token| {
        try args.append(token);
    }

    return args.toOwnedSlice();
}

fn spawnPager(allocator: std.mem.Allocator) !std.process.Child {
    const argv = try pager_args(allocator);
    return spawnProcess(allocator, argv);
}

fn spanGitApply(allocator: std.mem.Allocator) !std.process.Child {
    const argv = &.{ "git", "apply", "--reject", "--recount", "--unidiff-zero", "--inaccurate-eof", "-" };
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
