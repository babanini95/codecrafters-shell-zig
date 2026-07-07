const std = @import("std");
const builtin = @import("builtin");

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

    const path = init.environ_map.get("PATH").?;
    const path_sep: u8 = if (builtin.os.tag == .windows) ';' else ':';

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
                    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                    defer arena.deinit();
                    const allocator = arena.allocator();

                    var filepath: ?[]u8 = null;
                    var path_iterator = std.mem.splitScalar(u8, path, path_sep);

                    while (path_iterator.next()) |directory| {
                        const full_path = try std.fs.path.join(allocator, &.{ directory, command_str });
                        std.Io.Dir.cwd().access(init.io, full_path, .{}) catch continue;

                        filepath = try allocator.dupe(u8, full_path);
                    }

                    if (filepath == null) try stdout.interface.print("{s}: not found\n", .{args});
                } else {
                    try stdout.interface.print("{s} is a shell builtin\n", .{args});
                }
            },
            .invalid => try stdout.interface.print("{s}: command not found\n", .{command_str}),
        }
    }
}
