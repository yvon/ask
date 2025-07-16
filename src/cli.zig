const std = @import("std");
const usage = @embedFile("usage.txt");

pub const Config = struct {
    max_tokens: u32 = 5000,
    temperature: f32 = 0.0,
    prefill: ?[]const u8 = null,
    system: ?[]const u8 = null,
    model: []const u8 = "claude-sonnet-4-20250514",
    positional: []const []const u8 = &.{},
    interactive: bool = false,
    apply: bool = false,
};

pub fn parse(allocator: std.mem.Allocator, args: []const []const u8) Config {
    var array_list = std.ArrayList([]const u8).initCapacity(allocator, args.len) catch unreachable;
    var config: Config = .{};
    var i: usize = 0;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (eql(arg, "--help") or eql(arg, "-h")) {
            printUsage();
            std.process.exit(0);
        } else if (eql(arg, "-")) {
            config.interactive = true;
        } else if (int(args, "--max-tokens", &i)) |value| {
            config.max_tokens = value;
        } else if (float(args, "--temperature", &i)) |value| {
            config.temperature = value;
        } else if (string(args, "--prefill", &i)) |value| {
            config.prefill = value;
        } else if (string(args, "--system", &i)) |value| {
            config.system = value;
        } else if (string(args, "--model", &i)) |value| {
            config.model = value;
        } else if (eql(arg, "--diff") or eql(arg, "-d")) {
            // --diff takes precedence over --prefill
            config.prefill = "diff --git";
        } else if (eql(arg, "--apply") or eql(arg, "-a")) {
            config.prefill = "diff --git";
            config.apply = true;
        } else {
            if (arg[0] == '-') {
                fail("Invalid argument: {s}\n", .{arg});
            }
            array_list.append(arg) catch unreachable;
        }
    }

    config.positional = array_list.items;
    return config;
}

fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt, args);
    std.process.exit(1);
}

fn printUsage() void {
    std.debug.print("{s}\n", .{usage});
    std.process.exit(0);
}

fn eql(arg: []const u8, name: []const u8) bool {
    return std.mem.eql(u8, arg, name);
}

fn string(args: []const []const u8, name: []const u8, i: *usize) ?[]const u8 {
    if (!eql(args[i.*], name)) {
        return null;
    }

    i.* +|= 1;
    if (i.* >= args.len) {
        fail("Missing value for {s}\n", .{name});
    }

    return args[i.*];
}

fn int(args: []const []const u8, name: []const u8, i: *usize) ?u32 {
    const value = string(args, name, i) orelse return null;

    return std.fmt.parseInt(u32, value, 10) catch {
        fail("Invalid {s} value: {s}\n", .{ name, value });
    };
}

fn float(args: []const []const u8, name: []const u8, i: *usize) ?f32 {
    const value = string(args, name, i) orelse return null;

    return std.fmt.parseFloat(f32, value) catch {
        fail("Invalid {s} value: {s}\n", .{ name, value });
    };
}
