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
    stdout: anytype,
    redirect_file: ?std.Io.File,
) !void {
    const program_path = try findExecutable(allocator, io, path_env, command);

    if (program_path) |_| {
        var argv = std.ArrayList([]const u8).empty;
        defer argv.deinit(allocator);

        try argv.append(allocator, command);
        try argv.appendSlice(allocator, args);

        const spawn_options: std.process.SpawnOptions.StdIo = if (redirect_file) |f|
            .{ .file = f }
        else
            .inherit;

        var child_proc = try std.process.spawn(
            io,
            .{
                .argv = argv.items,
                .stdout = spawn_options,
            },
        );
        _ = try child_proc.wait(io);
    } else {
        try stdout.print("{s}: command not found\n", .{command});
    }

    // return null;
}
