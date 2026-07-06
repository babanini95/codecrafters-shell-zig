const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    var stdin_buffer: [4096]u8 = undefined;
    var stdin = std.Io.File.stdin().readerStreaming(init.io, &stdin_buffer);

    try stdout.interface.print("", .{});

    while (true) {
        try stdout.interface.print("$ ", .{});

        const command = try stdin.interface.takeDelimiter('\n');

        if (std.mem.eql(u8, command.?, "exit")) {
            break;
        } else if (std.mem.eql(u8, command.?[0..4], "echo")) {
            try stdout.interface.print("{s}\n", .{command.?[4..]});
        } else {
            try stdout.interface.print("{s}: command not found\n", .{command.?});
        }
    }
}
