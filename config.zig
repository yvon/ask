const std = @import("std");

pub const Config = struct {
    max_tokens: u32 = 5000,
    temperature: f32 = 0.0,
    prefill: ?[]const u8 = null,
    system: ?[]const u8 = null,
    model: []const u8 = "claude-sonnet-4-20250514",
    prompt: []const u8,
    api_key: []const u8,
};

const usage = @embedFile("usage.txt");

fn printUsage() void {
    std.debug.print("{s}\n", .{usage});
}

pub fn parseArgs(allocator: std.mem.Allocator) !Config {
    const args = try std.process.argsAlloc(allocator);

    // Check for help flag or no arguments
    if (args.len == 1) {
        printUsage();
        std.process.exit(0);
    }

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printUsage();
            std.process.exit(0);
        }
    }

    var max_tokens: u32 = 5000;
    var temperature: f32 = 0.0;
    var prefill: ?[]const u8 = null;
    var system: ?[]const u8 = null;
    var model: []const u8 = "claude-sonnet-4-20250514";
    var prompt_args = std.ArrayList([]const u8).init(allocator);
    var input_files = std.ArrayList([]const u8).init(allocator);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--max-tokens") and i + 1 < args.len) {
            max_tokens = std.fmt.parseInt(u32, args[i + 1], 10) catch {
                std.debug.print("Invalid max-tokens value: {s}\n", .{args[i + 1]});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--temperature") and i + 1 < args.len) {
            temperature = std.fmt.parseFloat(f32, args[i + 1]) catch {
                std.debug.print("Invalid temperature value: {s}\n", .{args[i + 1]});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--prefill") and i + 1 < args.len) {
            prefill = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--system") and i + 1 < args.len) {
            system = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--model") and i + 1 < args.len) {
            model = args[i + 1];
            i += 1;
        } else {
            // Check if the argument is a file that exists
            if (std.fs.cwd().access(args[i], .{})) {
                try input_files.append(args[i]);
            } else |_| {
                try prompt_args.append(args[i]);
            }
        }
    }

    // Read from stdin only if data is available
    var stdin_content: []const u8 = "";
    if (std.io.getStdIn().isTty() == false) {
        const stdin = std.io.getStdIn().reader();
        stdin_content = stdin.readAllAlloc(allocator, 1024 * 1024) catch "";
    }

    // Build prompt starting with file contents, then stdin content
    var prompt_builder = std.ArrayList(u8).init(allocator);

    // Add file contents first
    for (input_files.items) |file_path| {
        const file_content = std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024) catch |err| {
            std.debug.print("Error reading file '{s}': {any}\n", .{ file_path, err });
            std.process.exit(1);
        };

        if (prompt_builder.items.len > 0) {
            try prompt_builder.appendSlice("\n\n");
        }

        try prompt_builder.appendSlice("`");
        try prompt_builder.appendSlice(file_path);
        try prompt_builder.appendSlice("`:\n```");
        try prompt_builder.appendSlice(file_content);
        try prompt_builder.appendSlice("```\n");
    }

    if (stdin_content.len > 0) {
        if (prompt_builder.items.len > 0) {
            try prompt_builder.appendSlice("\n\n");
        }
        try prompt_builder.appendSlice(stdin_content);
    }

    for (prompt_args.items, 0..) |arg, idx| {
        if (prompt_builder.items.len > 0 or idx > 0) {
            try prompt_builder.append(' ');
        }
        try prompt_builder.appendSlice(arg);
    }

    const final_prompt = prompt_builder.items;

    if (final_prompt.len == 0) {
        std.debug.print("Error: No prompt provided via arguments or stdin\n\n", .{});
        printUsage();
        std.process.exit(1);
    }

    // Get API key from environment
    const api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch |err| {
        std.debug.print("Error: ANTHROPIC_API_KEY not found: {any}\n", .{err});
        std.debug.print("Please set your Anthropic API key as an environment variable.\n", .{});
        std.process.exit(1);
    };

    return Config{
        .max_tokens = max_tokens,
        .temperature = temperature,
        .prefill = prefill,
        .system = system,
        .model = model,
        .prompt = final_prompt,
        .api_key = api_key,
    };
}