const std = @import("std");
const builtin = @import("builtin");
const builtins = @import("builtins.zig");
const path_resolver = @import("path_resolver.zig");

const Commands = @import("command.zig").Commands;

pub fn main(init: std.process.Init) !void {
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    var stdin_buffer: [4096]u8 = undefined;
    var stdin = std.Io.File.stdin().readerStreaming(init.io, &stdin_buffer);

    const path = init.environ_map.get("PATH") orelse "";

    try stdout.interface.print("", .{});

    while (true) {
        try stdout.interface.print("$ ", .{});

        const line = try stdin.interface.takeDelimiter('\n') orelse "";
        const trimmed = if (builtin.os.tag == .windows)
            std.mem.trim(u8, line, "\r")
        else
            line;
        var t_command = std.mem.tokenizeAny(u8, trimmed, " \t");
        const command_str = t_command.next() orelse continue;
        const command = Commands.fromString(command_str) orelse .invalid;
        const args = t_command.rest();

        switch (command) {
            .exit => break,
            .echo => try builtins.handleEcho(&stdout, args),
            .type => try builtins.handleType(&stdout, init.io, path, args),
            .invalid => try builtins.handleInvalid(command_str, args, path, init.io, &stdout),
        }
    }
}
