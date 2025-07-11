const std = @import("std");
const config = @import("config.zig");

pub fn buildPrompt(allocator: std.mem.Allocator, parsed_args: config.ParsedArgs) ![]const u8 {
    // Read from stdin only if data is available
    var stdin_content: []const u8 = "";
    if (std.io.getStdIn().isTty() == false) {
        const stdin = std.io.getStdIn().reader();
        stdin_content = stdin.readAllAlloc(allocator, 1024 * 1024) catch "";
    }

    // Build prompt starting with file contents, then stdin content
    var prompt_builder = std.ArrayList(u8).init(allocator);

    // Add file contents first
    for (parsed_args.input_files.items) |file_path| {
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

    for (parsed_args.prompt_args.items, 0..) |arg, idx| {
        if (prompt_builder.items.len > 0 or idx > 0) {
            try prompt_builder.append(' ');
        }
        try prompt_builder.appendSlice(arg);
    }

    const final_prompt = prompt_builder.items;

    if (final_prompt.len == 0) {
        std.debug.print("Error: No prompt provided via arguments or stdin\n\n", .{});
        std.process.exit(1);
    }

    return final_prompt;
}

pub fn createConfig(parsed_args: config.ParsedArgs, prompt: []const u8) config.Config {
    return config.Config{
        .max_tokens = parsed_args.max_tokens,
        .temperature = parsed_args.temperature,
        .prefill = parsed_args.prefill,
        .system = parsed_args.system,
        .model = parsed_args.model,
        .prompt = prompt,
        .api_key = parsed_args.api_key,
    };
}