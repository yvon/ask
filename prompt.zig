const std = @import("std");

pub fn build(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
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

    if (!is_tty or words.items.len == 0) {
        std.debug.print("is_tty: {any}\n", .{is_tty});
        if (is_tty) {
            try std.io.getStdOut().writer().writeAll("> ");
        }
        const stdin = std.io.getStdIn().reader();
        const content = try stdin.readAllAlloc(allocator, 1024 * 1024);
        try writer.writeAll(content);
    }

    const sentence = try std.mem.join(allocator, " ", words.items);
    try prompt.appendSlice(sentence);
    return prompt.items;
}
