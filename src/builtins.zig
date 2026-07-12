const std = @import("std");
const Commands = @import("command.zig").Commands;
const path_resolver = @import("path_resolver.zig");
const zig_builtin = @import("builtin");

const os = zig_builtin.os.tag;

pub fn handleType(
    stdout: anytype,
    io: anytype,
    path_env: []const u8,
    arg: []const u8,
) !void {
    const cmd_arg = Commands.fromString(arg) orelse .invalid;

    if (cmd_arg != .invalid) {
        try stdout.interface.print("{s} is a shell builtin\n", .{arg});
        return;
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (try path_resolver.findExecutable(allocator, io, path_env, arg)) |filepath| {
        try stdout.interface.print("{s} is {s}\n", .{ arg, filepath });
    } else {
        try stdout.interface.print("{s}: not found\n", .{arg});
    }
}

pub fn handleEcho(stdout: anytype, args: []const u8) !void {
    try stdout.interface.print("{s}\n", .{args});
}

pub fn handleInvalid(
    cmd: []const u8,
    args: []const u8,
    path: []const u8,
    io: anytype,
    stdout: anytype,
) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try path_resolver.executeProgram(allocator, cmd, args, io, path, stdout);
}

pub fn handlePwd(
    io: anytype,
    stdout: anytype,
) !void {
    const cwd = std.Io.Dir.cwd();
    var buffer: [std.fs.max_path_bytes]u8 = undefined;

    if (cwd.realPathFile(io, ".", &buffer)) |len| {
        try stdout.interface.print("{s}\n", .{buffer[0..len]});
    } else |err| {
        try stdout.interface.print("Error: {any}\n", .{err});
    }
}

pub fn handleCd(
    io: anytype,
    path: []const u8,
    stdout: anytype,
) !void {
    var dir = std.Io.Dir.openDirAbsolute(io, path, .{}) catch {
        try stdout.interface.print("cd: {s}: No such file or directory\n", .{path});
        return;
    };
    defer dir.close(io);

    std.process.setCurrentDir(io, dir) catch
        try stdout.interface.print("cd: {s}: No such file or directory\n", .{path});
}
