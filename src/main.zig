const std = @import("std");
const builtin = @import("builtin");
const builtins = @import("builtins.zig");
const path_resolver = @import("path_resolver.zig");
const input_handler = @import("input_handler.zig");
const parser = @import("parser.zig");

const Commands = @import("command.zig").Commands;

pub fn main(init: std.process.Init) !void {
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    var stdin_buffer: [4096]u8 = undefined;
    var stdin = std.Io.File.stdin().readerStreaming(init.io, &stdin_buffer);

    const env = init.environ_map;

    try stdout.interface.print("", .{});

    while (true) {
        try stdout.interface.print("$ ", .{});

        const line = try stdin.interface.takeDelimiter('\n') orelse continue;
        const trimmed = if (builtin.os.tag == .windows)
            std.mem.trim(u8, line, "\r")
        else
            line;

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const allocator = arena.allocator();
        const t_command = try input_handler.tokenize(allocator, trimmed);
        const parsed = parser.parse(allocator, t_command) catch |err| {
            try stdout.interface.print("parse error: {s}\n", .{@errorName(err)});
            continue;
        };

        if (parsed.argv.len == 0) continue;

        const command_str = parsed.argv[0];
        const command = Commands.fromString(command_str) orelse .invalid;
        const args = parsed.argv[1..];

        var file_buffer: [4096]u8 = undefined;
        var file_writer_storage: ?std.Io.File.Writer = null;
        var out: *std.Io.Writer = &stdout.interface; // default target

        // find if any redirect targets fd 1 (stdout)
        var stdout_redirect: ?parser.Redirect = null;
        for (parsed.redirects) |r| {
            if (r.fd == 1) stdout_redirect = r; // last one wins if multiple
        }

        if (stdout_redirect) |r| {
            const file = try std.Io.Dir.cwd().createFile(init.io, r.target, .{
                .truncate = r.kind == .out,
            });

            file_writer_storage = file.writer(init.io, &file_buffer);

            if (r.kind == .append) {
                try file_writer_storage.?.seekTo(try file.length(init.io));
            }

            out = &file_writer_storage.?.interface;
        }
        defer if (file_writer_storage) |*fw| {
            fw.interface.flush() catch {};
            fw.file.close(init.io);
        };

        switch (command) {
            .exit => break,
            .echo => try builtins.handleEcho(out, args, allocator),
            .type => try builtins.handleType(out, init.io, env.get("PATH") orelse "", args),
            .pwd => try builtins.handlePwd(init.io, out),
            .cd => try builtins.handleCd(init.io, args, out, env),
            .invalid => try builtins.handleInvalid(
                command_str,
                args,
                env.get("PATH") orelse "",
                init.io,
                out,
                allocator,
            ),
        }
    }
}
