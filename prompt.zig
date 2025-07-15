const std = @import("std");
const cli = @import("cli.zig");

const c = @cImport({
    @cInclude("stdlib.h"); // free
    @cInclude("stdio.h"); // readline
    @cInclude("readline/readline.h");
    @cInclude("readline/history.h");
    @cInclude("unistd.h"); // open(), close(), dup2()
    @cInclude("fcntl.h"); // O_RDWR
});

fn readAllStdin(allocator: std.mem.Allocator, writer: anytype) !void {
    const stdin = std.io.getStdIn().reader();
    const content = try stdin.readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);
    try writer.writeAll(content);
}

fn readLine(writer: anytype) !void {
    const tty_fd = c.open("/dev/tty", c.O_RDWR);
    if (tty_fd == -1) {
        std.debug.print("Error opening /dev/tty\n", .{});
        return;
    }
    defer _ = c.close(tty_fd);

    // Redirect stdin to tty for readline
    _ = c.dup2(tty_fd, c.STDIN_FILENO);

    const line = c.readline("> ");

    if (line == null) {
        std.process.exit(0);
    }

    defer c.free(line);

    if (std.mem.len(line) > 0) {
        _ = c.add_history(line);
    }

    try writer.print("{s}\n", .{line});
}

fn initHistory(allocator: std.mem.Allocator) void {
    const home = std.process.getEnvVarOwned(allocator, "HOME") catch return;
    const history_path = std.fmt.allocPrint(allocator, "{s}/.ask_history", .{home}) catch return;
    defer allocator.free(history_path);

    _ = c.read_history(history_path.ptr);
}

fn saveHistory(allocator: std.mem.Allocator) void {
    const home = std.process.getEnvVarOwned(allocator, "HOME") catch return;
    const history_path = std.fmt.allocPrint(allocator, "{s}/.ask_history", .{home}) catch return;
    defer allocator.free(history_path);

    _ = c.write_history(history_path.ptr);
}

pub fn build(allocator: std.mem.Allocator, config: cli.Config, args: []const []const u8) ![]const u8 {
    initHistory(allocator);
    defer saveHistory(allocator);

    var files = try std.ArrayList([]const u8).initCapacity(allocator, args.len);
    var words = try std.ArrayList([]const u8).initCapacity(allocator, args.len);
    var prompt = std.ArrayList(u8).init(allocator);
    const writer = prompt.writer();

    for (args) |arg| {
        if (std.fs.cwd().access(arg, .{})) {
            try files.append(arg);
        } else |_| {
            try words.append(arg);
        }
    }

    for (files.items) |file| {
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "git", "diff", "--no-index", "/dev/null", file },
        }) catch |err| {
            std.debug.print("Error running diff for file '{s}': {any}\n", .{ file, err });
            continue;
        };

        try writer.print("```diff\n{s}```\n", .{result.stdout});
    }

    const is_tty = std.io.getStdIn().isTty();

    if (!is_tty) {
        try readAllStdin(allocator, writer);
    }

    if (config.interactive or is_tty and words.items.len == 0) {
        try readLine(writer);
    }

    if (words.items.len > 0) {
        const sentence = try std.mem.join(allocator, " ", words.items);
        try prompt.appendSlice(sentence);
    }

    return prompt.items;
}
