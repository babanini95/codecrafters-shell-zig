const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var stdout = std.Io.File.stdout().writer(init.io, &.{});

    // Suppress unused local constant error. Feel free to remove the line below.
    try stdout.interface.print("", .{});

    while (true) {
        // TODO: Uncomment the code below to pass the first stage
        try stdout.interface.print("$ ", .{});

        var stdin_buffer: [4096]u8 = undefined;
        var stdin = std.Io.File.stdin().readerStreaming(init.io, &stdin_buffer);

        const command = try stdin.interface.takeDelimiter('\r');

        try stdout.interface.print("asds{s}: command not found\n", .{command.?});
    }
}
