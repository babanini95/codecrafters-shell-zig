const std = @import("std");

const State = enum {
    normal,
    single_quoted,
    double_quoted,
    escaped,
    double_quoted_escape,
};

pub fn tokenize(
    allocator: std.mem.Allocator,
    input: []const u8,
) ![][]const u8 {
    var tokens = std.ArrayList([]const u8).empty;
    var current = std.ArrayList(u8).empty;
    var state = State.normal;
    var in_token = false;

    for (input) |c| {
        switch (state) {
            .normal => {
                switch (c) {
                    '\\' => state = .escaped,
                    '\'' => {
                        state = .single_quoted;
                        in_token = true;
                    },
                    '"' => {
                        state = .double_quoted;
                        in_token = true;
                    },
                    ' ', '\t' => {
                        if (in_token) {
                            try tokens.append(allocator, try current.toOwnedSlice(allocator));
                            in_token = false;
                        }
                    },
                    else => {
                        try current.append(allocator, c);
                        in_token = true;
                    },
                }
            },
            .single_quoted => {
                if (c == '\'')
                    state = .normal
                else
                    try current.append(allocator, c);
            },
            .double_quoted => {
                switch (c) {
                    '"' => state = .normal,
                    '\\' => state = .double_quoted_escape,
                    else => try current.append(allocator, c),
                }
            },
            .escaped => {
                try current.append(allocator, c);
                in_token = true;
                state = .normal;
            },
            .double_quoted_escape => {
                switch (c) {
                    '"', '\\' => try current.append(allocator, c),
                    else => {
                        try current.append(allocator, '\\');
                        try current.append(allocator, c);
                    },
                }
                state = .double_quoted;
            },
        }
    }

    if (state == .single_quoted or state == .double_quoted or state == .double_quoted_escape)
        return error.UnlcosedQuote;

    if (in_token) try tokens.append(allocator, try current.toOwnedSlice(allocator));

    return try tokens.toOwnedSlice(allocator);
}
