const std = @import("std");
const Commands = @import("command.zig").Commands;
const path_resolver = @import("path_resolver.zig");
const zig_builtin = @import("builtin");

const os = zig_builtin.os.tag;

pub fn handleType(
    stdout: anytype,
    stderr: anytype,
    io: anytype,
    path_env: []const u8,
    arg: [][]const u8,
) !void {
    if (arg.len != 1) return error.InvalidArgument;

    const cmd_arg = Commands.fromString(arg[0]) orelse .invalid;

    if (cmd_arg != .invalid) {
        try stdout.print("{s} is a shell builtin\n", .{arg[0]});
        return;
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (try path_resolver.findExecutable(
        allocator,
        io,
        path_env,
        arg[0],
    )) |filepath| {
        try stdout.print("{s} is {s}\n", .{ arg[0], filepath });
    } else {
        try stderr.print("{s}: not found\n", .{arg[0]});
    }
}

pub fn handleEcho(stdout: anytype, args: [][]const u8, allocator: std.mem.Allocator) !void {
    const str = try std.mem.join(allocator, " ", args);
    try stdout.print("{s}\n", .{str});
}

pub fn handleInvalid(
    cmd: []const u8,
    args: [][]const u8,
    path: []const u8,
    io: anytype,
    allocator: std.mem.Allocator,
    out: *std.Io.Writer,
    out_err: *std.Io.Writer,
) !void {
    for (args) |a| {
        out.print("arg: {s}", .{a});
    }
    try path_resolver.executeProgram(
        allocator,
        cmd,
        args,
        io,
        path,
        out,
        out_err,
    );
}

pub fn handlePwd(
    io: anytype,
    stdout: anytype,
    stderr: anytype,
) !void {
    const cwd = std.Io.Dir.cwd();
    var buffer: [std.fs.max_path_bytes]u8 = undefined;

    if (cwd.realPathFile(io, ".", &buffer)) |len| {
        try stdout.print("{s}\n", .{buffer[0..len]});
    } else |err| {
        try stderr.print("Error: {any}\n", .{err});
    }
}

pub fn handleCd(
    io: anytype,
    args: [][]const u8,
    stderr: anytype,
    env: anytype,
) !void {
    if (args.len != 1) return error.InvalidArgument;

    const path = args[0];

    const dir_path: []const u8 = if (std.mem.eql(u8, path, "~"))
        env.get("HOME") orelse env.get("USERPROFILE") orelse {
            try stderr.print("cd: HOME not set\n", .{});
            return;
        }
    else
        path;

    const open_result = if (std.fs.path.isAbsolute(dir_path))
        std.Io.Dir.openDirAbsolute(io, dir_path, .{})
    else
        std.Io.Dir.cwd().openDir(io, dir_path, .{});

    var dir = open_result catch {
        try stderr.print("cd: {s}: No such file or directory\n", .{dir_path});
        return;
    };
    defer dir.close(io);

    std.process.setCurrentDir(io, dir) catch
        try stderr.print("cd: {s}: No such file or directory\n", .{dir_path});
}
