const std = @import("std");

const State = enum { normal, single_quoted };

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
                    '\'' => {
                        state = .single_quoted;
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
        }
    }

    if (state == .single_quoted)
        return error.UnlcosedQuote;

    if (in_token) try tokens.append(allocator, try current.toOwnedSlice(allocator));

    return try tokens.toOwnedSlice(allocator);
}
