pub const Dependency = struct {
    name: []const u8,
    url: []const u8,
    hash: []const u8,
};

dependencies: []Dependency
