const std = @import("std");
const Commands = @import("command.zig").Commands;
const path_resolver = @import("path_resolver.zig");

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

    const result = try path_resolver.executeProgram(allocator, cmd, args, io, path);

    if (result) |res| {
        std.debug.print("before prompt\n", .{});
        try stdout.interface.print("{s}\n", .{res.stdout});
        std.debug.print("after prompt\n", .{});
        try stdout.interface.flush();
    } else {
        try stdout.interface.print("{s}: command not found\n", .{cmd});
    }
}
