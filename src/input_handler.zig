const std = @import("std");

const State = enum {
    normal,
    single_quoted,
    double_quoted,
    escaped,
    double_quoted_escape,
};

pub const Token = union(enum) {
    word: []const u8,
    redirect_out: u8,
    redirect_append: u8,
};

pub fn tokenize(allocator: std.mem.Allocator, input: []const u8) ![]Token {
    var tokens = std.ArrayList(Token).empty;
    var current = std.ArrayList(u8).empty;
    var state = State.normal;
    var i: usize = 0;

    while (i < input.len) {
        const c = input[i];
        switch (state) {
            .normal => {
                if (c == '\\') {
                    state = .escaped;
                } else if (c == '\'') {
                    state = .single_quoted;
                } else if (c == '"') {
                    state = .double_quoted;
                } else if (std.ascii.isWhitespace(c)) {
                    try flushWord(&tokens, allocator, &current);
                } else if (std.ascii.isDigit(c)) {
                    var j = i;
                    while (j < input.len and std.ascii.isDigit(input[j]))
                        j += 1;

                    if (j < input.len and input[j] == '>') {
                        try flushWord(&tokens, allocator, &current);

                        const fd = try std.fmt.parseInt(u8, input[i..j], 10);

                        if (j + 1 < input.len and input[j + 1] == '>') {
                            try tokens.append(allocator, .{ .redirect_append = fd });
                            i = j + 2;
                        } else {
                            try tokens.append(allocator, .{ .redirect_out = fd });
                            i = j + 1;
                        }
                        continue;
                    } else {
                        const end = if (j < input.len) j else input.len;
                        try current.appendSlice(allocator, input[i..end]);
                        i = end;
                        continue;
                    }
                } else if (c == '>') {
                    try flushWord(&tokens, allocator, &current);
                    if (i + 1 < input.len and input[i + 1] == '>') {
                        try tokens.append(allocator, .{ .redirect_append = 1 });
                        i += 2;
                    } else {
                        try tokens.append(allocator, .{ .redirect_out = 1 });
                        i += 1;
                    }

                    continue;
                } else {
                    try current.append(allocator, c);
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

        i += 1;
    }

    if (state == .single_quoted or state == .double_quoted or state == .double_quoted_escape)
        return error.UnclosedQuote;

    try flushWord(&tokens, allocator, &current);
    return tokens.toOwnedSlice(allocator);
}

fn flushWord(
    tokens: *std.ArrayList(Token),
    allocator: std.mem.Allocator,
    word: *std.ArrayList(u8),
) !void {
    if (word.items.len == 0)
        return;
    try tokens.append(
        allocator,
        .{
            .word = try word.toOwnedSlice(allocator),
        },
    );
}

const testing = std.testing;

fn freeTokens(allocator: std.mem.Allocator, tokens: []Token) void {
    for (tokens) |t| {
        switch (t) {
            .word => |w| allocator.free(w),
            else => {},
        }
    }
    allocator.free(tokens);
}

test "splits plain words on whitespace" {
    const tokens = try tokenize(testing.allocator, "echo hi");
    defer freeTokens(testing.allocator, tokens);

    try testing.expectEqual(@as(usize, 2), tokens.len);
    try testing.expectEqualStrings("echo", tokens[0].word);
    try testing.expectEqualStrings("hi", tokens[1].word);
}

test "single quotes preserve spaces" {
    const tokens = try tokenize(testing.allocator, "echo 'hi there'");
    defer freeTokens(testing.allocator, tokens);

    try testing.expectEqual(@as(usize, 2), tokens.len);
    try testing.expectEqualStrings("echo", tokens[0].word);
    try testing.expectEqualStrings("hi there", tokens[1].word);
}

test "backslash escape prevents word split on space" {
    const tokens = try tokenize(testing.allocator, "a\\ b");
    defer freeTokens(testing.allocator, tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqualStrings("a b", tokens[0].word);
}

test "double quotes: escaped quote stays literal, string not closed early" {
    const tokens = try tokenize(testing.allocator, "\"a\\\"b\"");
    defer freeTokens(testing.allocator, tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqualStrings("a\"b", tokens[0].word);
}

test "double quotes: backslash before non-special char is kept literally" {
    const tokens = try tokenize(testing.allocator, "\"a\\nb\"");
    defer freeTokens(testing.allocator, tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    // literal backslash + 'n', NOT a newline
    try testing.expectEqualStrings("a\\nb", tokens[0].word);
}

test "bare > defaults to fd 1" {
    const tokens = try tokenize(testing.allocator, ">");
    defer freeTokens(testing.allocator, tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(Token{ .redirect_out = 1 }, tokens[0]);
}

test ">> defaults to fd 1 append" {
    const tokens = try tokenize(testing.allocator, ">>");
    defer freeTokens(testing.allocator, tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(Token{ .redirect_append = 1 }, tokens[0]);
}

test "numeric fd redirect: 2>" {
    const tokens = try tokenize(testing.allocator, "2>");
    defer freeTokens(testing.allocator, tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(Token{ .redirect_out = 2 }, tokens[0]);
}

test "numeric fd redirect append: 2>>" {
    const tokens = try tokenize(testing.allocator, "2>>");
    defer freeTokens(testing.allocator, tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(Token{ .redirect_append = 2 }, tokens[0]);
}

test "word, redirect, and target word together" {
    const tokens = try tokenize(testing.allocator, "echo 2>out.txt");
    defer freeTokens(testing.allocator, tokens);

    try testing.expectEqual(@as(usize, 3), tokens.len);
    try testing.expectEqualStrings("echo", tokens[0].word);
    try testing.expectEqual(Token{ .redirect_out = 2 }, tokens[1]);
    try testing.expectEqualStrings("out.txt", tokens[2].word);
}

test "unclosed single quote is an error" {
    try testing.expectError(error.UnclosedQuote, tokenize(testing.allocator, "'unclosed"));
}

test "unclosed double quote is an error" {
    try testing.expectError(error.UnclosedQuote, tokenize(testing.allocator, "\"unclosed"));
}
