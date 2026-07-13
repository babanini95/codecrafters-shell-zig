const std = @import("std");
const Commands = @import("command.zig").Commands;
const path_resolver = @import("path_resolver.zig");
const zig_builtin = @import("builtin");

const os = zig_builtin.os.tag;

pub fn handleType(
    stdout: anytype,
    io: anytype,
    path_env: []const u8,
    arg: [][]const u8,
) !void {
    if (arg.len != 1) return error.InvalidArgument;

    const cmd_arg = Commands.fromString(arg[0]) orelse .invalid;

    if (cmd_arg != .invalid) {
        try stdout.interface.print("{s} is a shell builtin\n", .{arg[0]});
        return;
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (try path_resolver.findExecutable(allocator, io, path_env, arg[0])) |filepath| {
        try stdout.interface.print("{s} is {s}\n", .{ arg[0], filepath });
    } else {
        try stdout.interface.print("{s}: not found\n", .{arg[0]});
    }
}

pub fn handleEcho(stdout: anytype, args: [][]const u8, allocator: std.mem.Allocator) !void {
    const str = try std.mem.concat(allocator, u8, args);
    try stdout.interface.print("{s}\n", .{str});
}

pub fn handleInvalid(
    cmd: []const u8,
    args: [][]const u8,
    path: []const u8,
    io: anytype,
    stdout: anytype,
    allocator: std.mem.Allocator,
) !void {
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
    args: [][]const u8,
    stdout: anytype,
    env: anytype,
) !void {
    if (args.len != 1) return error.InvalidArgument;

    const path = args[0];

    const dir_path: []const u8 = if (std.mem.eql(u8, path, "~"))
        env.get("HOME") orelse env.get("USERPROFILE") orelse {
            try stdout.interface.print("cd: HOME not set\n", .{});
            return;
        }
    else
        path;

    const open_result = if (std.fs.path.isAbsolute(dir_path))
        std.Io.Dir.openDirAbsolute(io, dir_path, .{})
    else
        std.Io.Dir.cwd().openDir(io, dir_path, .{});

    var dir = open_result catch {
        try stdout.interface.print("cd: {s}: No such file or directory\n", .{dir_path});
        return;
    };
    defer dir.close(io);

    std.process.setCurrentDir(io, dir) catch
        try stdout.interface.print("cd: {s}: No such file or directory\n", .{dir_path});
}
