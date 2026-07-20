const std = @import("std");
const builtin = @import("builtin");

pub fn findExecutable(
    allocator: std.mem.Allocator,
    io: anytype,
    path_env: []const u8,
    cmd_name: []const u8,
) !?[]u8 {
    const is_windows = builtin.os.tag == .windows;
    const path_sep: u8 = if (is_windows) ';' else ':';
    const extensions: []const []const u8 = if (is_windows)
        &.{ "", ".exe", ".cmd", ".bat", ".com" }
    else
        &.{""};

    var path_iterator = std.mem.splitScalar(u8, path_env, path_sep);

    while (path_iterator.next()) |directory| {
        for (extensions) |ext| {
            const candidate = std.mem.concat(allocator, u8, &.{ cmd_name, ext }) catch continue;
            defer allocator.free(candidate);

            const full_path = std.fs.path.join(allocator, &.{ directory, candidate }) catch continue;

            // Check executable access
            if (std.Io.Dir.cwd().access(io, full_path, .{ .execute = true })) |_| {
                return full_path; // Caller owns the returned memory
            } else |_| {
                allocator.free(full_path);
            }
        }
    }

    return null;
}

pub fn executeProgram(
    allocator: std.mem.Allocator,
    command: []const u8,
    args: [][]const u8,
    io: anytype,
    path_env: []const u8,
    out: *std.Io.Writer,
    out_err: *std.Io.Writer,
) !void {
    const program_path = try findExecutable(allocator, io, path_env, command);

    if (program_path) |_| {
        var argv = std.ArrayList([]const u8).empty;
        defer argv.deinit(allocator);

        try argv.append(allocator, command);
        try argv.appendSlice(allocator, args);

        var child_proc = try std.process.spawn(
            io,
            .{
                .argv = argv.items,
                .stdout = .pipe,
                .stderr = .pipe,
            },
        );

        if (child_proc.stdout) |*child_stdout| {
            var read_buf: [4096]u8 = undefined;
            var reader = child_stdout.readerStreaming(io, &read_buf);

            while (true) {
                const bytes_read = reader.interface.readSliceShort(&read_buf) catch |err| {
                    if (err == error.EndOfStream) break;
                    return err;
                };
                if (bytes_read == 0) break;
                try out.writeAll(read_buf[0..bytes_read]);
            }
        }

        // Read stderr stream from child and forward it to our target error writer ('out_err')
        if (child_proc.stderr) |*child_stderr| {
            var read_buf: [4096]u8 = undefined;
            var reader = child_stderr.readerStreaming(io, &read_buf);

            while (true) {
                const bytes_read = reader.interface.readSliceShort(&read_buf) catch |err| {
                    if (err == error.EndOfStream) break;
                    return err;
                };
                if (bytes_read == 0) break;
                try out_err.writeAll(read_buf[0..bytes_read]);
            }
        }

        _ = try child_proc.wait(io);
    } else {
        try out_err.print("{s}: command not found\n", .{command});
    }

    // return null;
}
