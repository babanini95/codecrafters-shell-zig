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
