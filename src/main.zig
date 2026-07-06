const std = @import("std");

const Commands = enum {
    exit,
    echo,
    type,
    invalid,

    pub fn fromString(str: []const u8) ?Commands {
        return std.meta.stringToEnum(Commands, str);
    }
};

pub fn main(init: std.process.Init) !void {
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    var stdin_buffer: [4096]u8 = undefined;
    var stdin = std.Io.File.stdin().readerStreaming(init.io, &stdin_buffer);

    try stdout.interface.print("", .{});

    while (true) {
        try stdout.interface.print("$ ", .{});

        const line = try stdin.interface.takeDelimiter('\n');
        var t_command = std.mem.tokenizeAny(u8, std.mem.trim(u8, line.?, "\r"), " \t");
        const command_str = t_command.next().?;
        const command = Commands.fromString(command_str) orelse .invalid;
        const args = t_command.rest();

        switch (command) {
            .exit => break,
            .echo => try stdout.interface.print("{s}\n", .{args}),
            .type => {
                const arg = Commands.fromString(args) orelse .invalid;
                if (arg == .invalid) {
                    try stdout.interface.print("{s}: not found\n", .{args});
                } else {
                    try stdout.interface.print("{s} is a shell builtin\n", .{args});
                }
            },
            .invalid => try stdout.interface.print("{s}: command not found\n", .{command_str}),
        }

        // if (std.mem.eql(u8, command, "exit")) {
        //     break;
        // } else if (std.mem.eql(u8, command, "echo")) {
        //     try stdout.interface.print("{s}\n", .{args});
        // } else if (std.mem.eql(u8, command, "type")) {
        //     const com = std.meta.stringToEnum(Commands, args) orelse {
        //         try stdout.interface.print("{s}: not found\n", .{args});
        //         continue;
        //     };

        //     try stdout.interface.print("{s} is a shell builtin\n", .{std.enums.tagName(Commands, com).?});
        // } else {
        //     try stdout.interface.print("{s}: command not found\n", .{command});
        // }
    }
}
