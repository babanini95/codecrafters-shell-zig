const std = @import("std");
const Token = @import("input_handler.zig").Token;

pub const RedirectKind = enum { out, append };

pub const Redirect = struct {
    kind: RedirectKind,
    fd: u8,
    target: []const u8,
};

pub const ParsedCommand = struct {
    argv: [][]const u8,
    redirects: []Redirect,
};

pub fn parse(allocator: std.mem.Allocator, tokens: []const Token) !ParsedCommand {
    var words = std.ArrayList([]const u8).empty;
    var redirects = std.ArrayList(Redirect).empty;

    var i: usize = 0;
    while (i < tokens.len) : (i += 1) {
        switch (tokens[i]) {
            .word => |w| try words.append(allocator, w),
            .redirect_out => |fd| {
                i += 1;
                if (i >= tokens.len or tokens[i] != .word)
                    return error.MissingRedirectTarget;
                try redirects.append(allocator, .{ .kind = .out, .fd = fd, .target = tokens[i].word });
            },
            .redirect_append => |fd| {
                i += 1;
                if (i >= tokens.len or tokens[i] != .word)
                    return error.MissingRedirectTarget;
                try redirects.append(allocator, .{ .kind = .append, .fd = fd, .target = tokens[i].word });
            },
        }
    }

    return .{
        .argv = try words.toOwnedSlice(allocator),
        .redirects = try redirects.toOwnedSlice(allocator),
    };
}

const testing = std.testing;

test "parse: plain words, no redirects" {
    const allocator = testing.allocator;
    const tokens = [_]Token{
        .{ .word = "echo" },
        .{ .word = "hi" },
    };
    const parsed = try parse(allocator, &tokens);
    defer allocator.free(parsed.argv);
    defer allocator.free(parsed.redirects);

    try testing.expectEqual(@as(usize, 2), parsed.argv.len);
    try testing.expectEqualStrings("echo", parsed.argv[0]);
    try testing.expectEqualStrings("hi", parsed.argv[1]);
    try testing.expectEqual(@as(usize, 0), parsed.redirects.len);
}

test "parse: redirect_out captured, target word excluded from argv" {
    const allocator = testing.allocator;
    const tokens = [_]Token{
        .{ .word = "echo" },
        .{ .word = "hi" },
        .{ .redirect_out = 1 },
        .{ .word = "out.txt" },
    };
    const parsed = try parse(allocator, &tokens);
    defer allocator.free(parsed.argv);
    defer allocator.free(parsed.redirects);

    try testing.expectEqual(@as(usize, 2), parsed.argv.len); // "out.txt" NOT in argv
    try testing.expectEqual(@as(usize, 1), parsed.redirects.len);
    try testing.expectEqual(RedirectKind.out, parsed.redirects[0].kind);
    try testing.expectEqual(@as(u8, 1), parsed.redirects[0].fd);
    try testing.expectEqualStrings("out.txt", parsed.redirects[0].target);
}

test "parse: redirect_append captured correctly" {
    const allocator = testing.allocator;
    const tokens = [_]Token{
        .{ .word = "echo" },
        .{ .redirect_append = 1 },
        .{ .word = "log.txt" },
    };
    const parsed = try parse(allocator, &tokens);
    defer allocator.free(parsed.argv);
    defer allocator.free(parsed.redirects);

    try testing.expectEqual(RedirectKind.append, parsed.redirects[0].kind);
    try testing.expectEqualStrings("log.txt", parsed.redirects[0].target);
}

test "parse: last redirect for same fd wins" {
    const allocator = testing.allocator;
    const tokens = [_]Token{
        .{ .word = "echo" },
        .{ .redirect_out = 1 },
        .{ .word = "a.txt" },
        .{ .redirect_out = 1 },
        .{ .word = "b.txt" },
    };
    const parsed = try parse(allocator, &tokens);
    defer allocator.free(parsed.argv);
    defer allocator.free(parsed.redirects);

    // parse() itself just collects both; "last wins" logic lives in main's loop.
    // So test that BOTH show up here, in order:
    try testing.expectEqual(@as(usize, 2), parsed.redirects.len);
    try testing.expectEqualStrings("a.txt", parsed.redirects[0].target);
    try testing.expectEqualStrings("b.txt", parsed.redirects[1].target);
}

test "parse: redirect with no target word errors" {
    const allocator = testing.allocator;
    const tokens = [_]Token{
        .{ .word = "echo" },
        .{ .redirect_out = 1 },
    };
    try testing.expectError(error.MissingRedirectTarget, parse(allocator, &tokens));
}

test "parse: empty token list gives empty argv" {
    const allocator = testing.allocator;
    const tokens = [_]Token{};
    const parsed = try parse(allocator, &tokens);
    defer allocator.free(parsed.argv);
    defer allocator.free(parsed.redirects);

    try testing.expectEqual(@as(usize, 0), parsed.argv.len);
    try testing.expectEqual(@as(usize, 0), parsed.redirects.len);
}
