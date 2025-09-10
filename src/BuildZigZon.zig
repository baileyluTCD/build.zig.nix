pub const Dependency = union(enum) {
    name: []const u8,
    url: []const u8,
    hash: []const u8,
};

dependencies: []Dependency
