//! `build.zig.nix` can be used to produce a nix expression representing
//! the dependencies needed to build a zig project.
//!
//! # Usage
//!
//! `build.zig.nix` should be imported in and used by your build system as follows:
//!
//! ```zig
//! TODO: fill out build system example
//! ```
//!
//! You may use one of a variety of functions in this library for your
//! build steps, however the recommended interface is `writeNixPackageSetForFile`,
//! which will read and parse your `build.zig.zon` file and write out a
//! `deps.nix` file for you.

const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const zon = std.zon;

const Io = std.Io;

const nix_expression = @import("./nix_expression.zig");

const BuildZigZon = @import("./BuildZigZon.zig");

/// Write Nix Package Set For File
///
/// Opens and parses a `build.zig.zon` file, produces a nix
/// expression for it's dependencies and writes it to the provided `deps.nix` path.
pub fn writeNixPackageSetForFile(
    allocator: mem.Allocator,
    build_zig_zon_path: []const u8,
    deps_nix_path: []const u8,
    diagnostics: ?*std.ArrayList([]const u8),
) !void {
    const deps_nix_contents = try generateNixPackageSetForFile(
        allocator,
        build_zig_zon_path,
        diagnostics,
    );
    defer allocator.free(deps_nix_contents);

    var deps_nix = try fs.cwd().createFile(deps_nix_path, .{});
    defer deps_nix.close();

    var buffer: [1024]u8 = undefined;
    var file_writer = deps_nix.writer(&buffer);

    var writer = file_writer.interface;
    try writer.writeAll(deps_nix_contents);

    try file_writer.end();
}

/// Generate Nix Package Set For File
///
/// Opens and parses a `build.zig.zon` file, and produces an string containing
/// the file contents for a nix expression based on the dependencies needed for
/// that `build.zig.zon` file.
///
/// The caller is responsible for the memory of the string returned.
pub fn generateNixPackageSetForFile(
    allocator: mem.Allocator,
    build_zig_zon_path: []const u8,
    diagnostics: ?*std.ArrayList([]const u8),
) ![]const u8 {
    var build_zig_zon = try fs.cwd().openFile(build_zig_zon_path, .{});
    defer build_zig_zon.close();

    var buffer: [1024]u8 = undefined;
    const file_reader = build_zig_zon.reader(&buffer);

    var reader = file_reader.interface;
    const zon_contents = try reader.allocRemaining(allocator, .unlimited);
    defer allocator.free(zon_contents);

    return generateNixPackageSetForString(
        allocator,
        zon_contents[0..zon_contents.len :0],
        diagnostics,
    );
}

/// Generate Nix Package Set For String
///
/// Parses the string contents of a `build.zig.zon` file, and
/// produces an string containing the file contents for a nix
/// expression based on the dependencies needed for that
/// `build.zig.zon` file.
///
/// The caller is responsible for the memory of the string returned.
pub fn generateNixPackageSetForString(
    allocator: mem.Allocator,
    build_zig_zon: [:0]const u8,
    diagnostics: ?*std.ArrayList([]const u8),
) ![]const u8 {
    const parsed_zon = try BuildZigZon.parse(allocator, build_zig_zon, diagnostics);
    defer parsed_zon.deinit(allocator);

    return generateNixPackageSetForDependencies(
        allocator,
        parsed_zon.dependencies,
    );
}

/// Generate Nix Package Set For a list of Dependencies
///
/// Converts the typed representation of a `build.zig.zon` file's dependencies
/// into produces a string containing the file contents for a nix expression.
///
/// The caller is responsible for the memory of the string returned.
pub fn generateNixPackageSetForDependencies(
    allocator: mem.Allocator,
    dependencies: []const BuildZigZon.Dependency,
) ![]const u8 {
    const bufferLength = nix_expression.calculateLength(dependencies);
    const buffer = try allocator.alloc(u8, bufferLength);

    var writer = Io.Writer.fixed(buffer);
    try nix_expression.write(&writer, dependencies);

    return buffer;
}

const testing = std.testing;

test "a stringified build.zig.zon produces an output expression" {
    var diagnostics: std.ArrayList([]const u8) = .empty;
    defer diagnostics.deinit(testing.allocator);

    const output = try generateNixPackageSetForString(
        testing.allocator,
        BuildZigZon.test_build_zig_zon,
        &diagnostics,
    );
    defer testing.allocator.free(output);

    try testing.expectEqual(diagnostics.items.len, 0);

    try testing.expect(mem.containsAtLeast(u8, output, 1, "dep_one"));
    try testing.expect(mem.containsAtLeast(u8, output, 1, "dep_two"));
}

test "a list of dependencies produces an output expression" {
    const output = try generateNixPackageSetForDependencies(
        testing.allocator,
        BuildZigZon.Dependency.test_dependencies,
    );
    defer testing.allocator.free(output);

    try testing.expect(mem.containsAtLeast(u8, output, 1, "dep-one"));
    try testing.expect(mem.containsAtLeast(u8, output, 1, "dep-two"));
}

test {
    std.testing.refAllDecls(@This());
}
