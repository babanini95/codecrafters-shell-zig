const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    var stdin_buffer: [4096]u8 = undefined;
    var stdin = std.Io.File.stdin().readerStreaming(init.io, &stdin_buffer);

    try stdout.interface.print("", .{});

    while (true) {
        try stdout.interface.print("$ ", .{});

        const bare_line = try stdin.interface.takeDelimiter('\n');
        const command = std.mem.trim(u8, bare_line.?, "\r");

        if (std.mem.eql(u8, command, "exit")) {
            break;
        } else if (std.mem.startsWith(u8, command, "echo")) {
            try stdout.interface.print("{s}\n", .{command[5..]});
        } else {
            try stdout.interface.print("{s}: command not found\n", .{command});
        }
    }
}
