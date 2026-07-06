const std = @import("std");

const Commands = enum { exit, echo, type };

pub fn main(init: std.process.Init) !void {
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    var stdin_buffer: [4096]u8 = undefined;
    var stdin = std.Io.File.stdin().readerStreaming(init.io, &stdin_buffer);

    try stdout.interface.print("", .{});

    while (true) {
        try stdout.interface.print("$ ", .{});

        const line = try stdin.interface.takeDelimiter('\n');
        var t_command = std.mem.tokenizeAny(u8, std.mem.trim(u8, line.?, "\r"), " \t");
        const command = t_command.next().?;
        const args = t_command.rest();

        if (std.mem.eql(u8, command, "exit")) {
            break;
        } else if (std.mem.eql(u8, command, "echo")) {
            try stdout.interface.print("{s}\n", .{args});
        } else if (std.mem.eql(u8, command, "type")) {
            const com = std.meta.stringToEnum(Commands, args) orelse {
                try stdout.interface.print("{s}: not found\n", .{args});
                continue;
            };

            try stdout.interface.print("{s} is a shell builtin\n", .{std.enums.tagName(Commands, com).?});
        } else {
            try stdout.interface.print("{s}: command not found\n", .{command});
        }
    }
}
