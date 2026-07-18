const std = @import("std");
const builtin = @import("builtin");
const builtins = @import("builtins.zig");
const path_resolver = @import("path_resolver.zig");
const input_handler = @import("input_handler.zig");
const parser = @import("parser.zig");

const Commands = @import("command.zig").Commands;

pub fn main(init: std.process.Init) !void {
    var stderr = std.Io.File.stderr().writer(init.io, &.{});
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

        var err_file_buffer: [4069]u8 = undefined;
        var err_file_writer_storage: ?std.Io.File.Writer = null;
        var out_err: *std.Io.Writer = &stderr.interface;

        var stdout_redirect: ?parser.Redirect = null;
        var stderr_redirect: ?parser.Redirect = null;
        for (parsed.redirects) |r| {
            if (r.fd == 1) stdout_redirect = r;
            if (r.fd == 2) stderr_redirect = r;
        }

        if (stdout_redirect) |r| {
            const file = try std.Io.Dir.cwd().createFile(init.io, r.target, .{
                .truncate = r.kind == .out,
                .read = r.kind == .append,
            });

            file_writer_storage = file.writer(init.io, &file_buffer);

            if (r.kind == .append) {
                const stat = try file.stat(init.io);
                try file_writer_storage.?.seekTo(stat.size);
            }

            out = &file_writer_storage.?.interface;
        }

        if (stderr_redirect) |r| {
            const file = try std.Io.Dir.cwd().createFile(init.io, r.target, .{
                .truncate = r.kind == .out,
                .read = r.kind == .append,
            });
            err_file_writer_storage = file.writer(init.io, &err_file_buffer);
            if (r.kind == .append) {
                const stat = try file.stat(init.io);
                try err_file_writer_storage.?.seekTo(stat.size);
            }
            out_err = &err_file_writer_storage.?.interface;
        }
        defer if (file_writer_storage) |*fw| {
            fw.interface.flush() catch {};
            fw.file.close(init.io);
        };
        defer if (err_file_writer_storage) |*fw| {
            fw.interface.flush() catch {};
            fw.file.close(init.io);
        };

        const redirect_file = if (file_writer_storage) |*fw|
            fw.file
        else
            null;

        const redirect_err_file = if (err_file_writer_storage) |*fw|
            fw.file
        else
            null;

        switch (command) {
            .exit => break,
            .echo => try builtins.handleEcho(out, args, allocator),
            .type => try builtins.handleType(out, out_err, init.io, env.get("PATH") orelse "", args),
            .pwd => try builtins.handlePwd(init.io, out, out_err),
            .cd => try builtins.handleCd(init.io, args, out_err, env),
            .invalid => try builtins.handleInvalid(
                command_str,
                args,
                env.get("PATH") orelse "",
                init.io,
                out_err,
                allocator,
                redirect_file,
                redirect_err_file,
            ),
        }
    }
}
