const std = @import("std");
pub const Commands = enum {
    exit,
    echo,
    type,
    pwd,
    cd,
    invalid,

    pub fn fromString(str: []const u8) ?Commands {
        return std.meta.stringToEnum(Commands, str);
    }
};
