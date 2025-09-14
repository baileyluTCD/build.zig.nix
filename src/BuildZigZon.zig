const std = @import("std");
const zig = std.zig;
const mem = std.mem;
const meta = std.meta;

dependencies: []Dependency,
ast: *zig.Ast,

const Self = @This();

pub const BuildZigZonError = error{IncorrectFormat};

pub const Dependency = struct {
    name: []const u8,
    url: []const u8,
    hash: []const u8,

    pub fn parse(
        allocator: mem.Allocator,
        ast: zig.Ast,
        name: []const u8,
        node: zig.Ast.Node.Index,
        diagnostics: ?*std.ArrayList([]const u8),
    ) !Dependency {
        var buf: [2]zig.Ast.Node.Index = undefined;
        const struct_init = ast.fullStructInit(&buf, node) orelse {
            if (diagnostics) |diag|
                try diag.append(
                    allocator,
                    "expected dependency expression to be a struct",
                );

            return BuildZigZonError.IncorrectFormat;
        };

        var url: ?[]const u8 = null;
        var hash: ?[]const u8 = null;
        for (struct_init.ast.fields) |field_init| {
            const value_token = ast.firstToken(field_init);
            const name_token = value_token - 2;
            const field_name = try identifierTokenString(allocator, ast, name_token);

            if (meta.eql(field_name, "url")) {
                url = try identifierTokenString(allocator, ast, value_token);
            } else if (meta.eql(field_name, "hash")) {
                hash = try identifierTokenString(allocator, ast, value_token);
            }
        }

        return Dependency{
            .name = name,
            .url = url orelse {
                if (diagnostics) |diag|
                    try diag.append(
                        allocator,
                        "expected url length to be higher than 0",
                    );

                return BuildZigZonError.IncorrectFormat;
            },
            .hash = hash orelse {
                if (diagnostics) |diag|
                    try diag.append(
                        allocator,
                        "expected hash length to be higher than 0",
                    );

                return BuildZigZonError.IncorrectFormat;
            },
        };
    }

    pub const test_dependencies: []const Dependency = &.{
        Dependency{
            .name = "dep-one",
            .url = "git+https://github.com/dep/one",
            .hash = "dep_one-0.2.0-Ej1rkNTJAACihOoSX8A1d3UceliSUTSmHtJ7jaOjWb4V",
        },
        Dependency{
            .name = "dep_two",
            .url = "https://dep-two.com/tarball",
            .hash = "dep_two-0.1.1-NmT1Q_l_IwC-WP5r0ZzuU5PeGmCZNh_-syZmEbDeAN3P",
        },
    };
};

const mode = zig.Ast.Mode.zon;

pub fn parse(
    allocator: mem.Allocator,
    source: [:0]const u8,
    diagnostics: ?*std.ArrayList([]const u8),
) !Self {
    var ast = try zig.Ast.parse(
        allocator,
        source,
        mode,
    );

    const root_node = ast.nodeData(.root).node;

    var buf: [2]zig.Ast.Node.Index = undefined;
    const struct_init = ast.fullStructInit(&buf, root_node) orelse {
        if (diagnostics) |diag|
            try diag.append(
                allocator,
                "expected top level expression to be a struct",
            );

        return BuildZigZonError.IncorrectFormat;
    };

    const dependencies = for (struct_init.ast.fields) |field_init| {
        const name_token = ast.firstToken(field_init) - 2;
        const field_name = try identifierTokenString(allocator, ast, name_token);

        if (meta.eql(field_name, "dependencies")) {
            break try parseDependencies(allocator, ast, field_init, diagnostics);
        }
    } else return BuildZigZonError.IncorrectFormat;

    return Self{
        .ast = &ast,
        .dependencies = dependencies,
    };
}

fn identifierTokenString(allocator: mem.Allocator, ast: zig.Ast, token: zig.Ast.TokenIndex) ![]const u8 {
    std.debug.assert(ast.tokenTag(token) == .identifier);

    const ident_name = ast.tokenSlice(token);
    if (!mem.startsWith(u8, ident_name, "@")) {
        return ident_name;
    }

    return zig.string_literal.parseAlloc(allocator, ident_name);
}

fn parseDependencies(
    allocator: mem.Allocator,
    ast: zig.Ast,
    node: zig.Ast.Node.Index,
    diagnostics: ?*std.ArrayList([]const u8),
) ![]Dependency {
    var buf: [2]zig.Ast.Node.Index = undefined;
    const struct_init = ast.fullStructInit(&buf, node) orelse {
        if (diagnostics) |diag|
            try diag.append(
                allocator,
                "expected dependency expression to be a struct",
            );

        return BuildZigZonError.IncorrectFormat;
    };

    var dependencies: std.ArrayList(Dependency) = .empty;
    defer dependencies.deinit(allocator);

    for (struct_init.ast.fields) |field_init| {
        const name_token = ast.firstToken(field_init) - 2;
        const dep_name = try identifierTokenString(allocator, ast, name_token);
        const dep = try Dependency.parse(allocator, ast, dep_name, field_init, diagnostics);
        try dependencies.append(allocator, dep);
    }

    return dependencies.toOwnedSlice(allocator);
}

pub fn deinit(self: Self, allocator: mem.Allocator) void {
    defer self.ast.deinit(allocator);
    defer allocator.free(self.dependencies);
}

const testing = std.testing;

pub const test_build_zig_zon =
    \\.{
    \\    .name = .test_file,
    \\    .version = "0.0.0",
    \\    .fingerprint = 0x1a27cf18ea73efc8, 
    \\    .minimum_zig_version = "0.15.1",
    \\    .dependencies = .{
    \\        .dep_one = .{
    \\            .url = "git+https://github.com/dep/one",
    \\            .hash = "dep_one-0.2.0-Ej1rkNTJAACihOoSX8A1d3UceliSUTSmHtJ7jaOjWb4V",
    \\        },
    \\        .dep_two = .{
    \\            .url = "https://dep-two.com/tarball",
    \\            .hash = "dep_two-0.1.1-NmT1Q_l_IwC-WP5r0ZzuU5PeGmCZNh_-syZmEbDeAN3P",
    \\        },
    \\    },
    \\    .paths = .{
    \\        "build.zig",
    \\        "build.zig.zon",
    \\        "src",
    \\    },
    \\}
;

test "parses dependencies correctly" {
    var diagnostics: std.ArrayList([]const u8) = .empty;

    const build_zig_zon = try Self.parse(
        testing.allocator,
        test_build_zig_zon,
        &diagnostics,
    );

    try testing.expectEqual(diagnostics.items.len, 0);

    defer build_zig_zon.deinit(testing.allocator);
}
