//!
//! Arena Allocator
//! copyright © github.com/shaheerbits
//!

const std = @import("std");

pub const ArenaAllocator = struct {
    /// The buffer that defines a memory space
    buffer: []u8,
    /// The bookmark that defines the offset (used memory)
    offset: usize,

    /// Initializes an ArenaAllocator. Returns a reference to the allocator.
    pub fn init(buffer: []u8) ArenaAllocator {
        return .{
            .buffer = buffer,
            .offset = 0,
        };
    }

    /// Allocates and return memory of a specific size.
    pub fn alloc(self: *ArenaAllocator, size: usize) ![]u8 {
        // If memory space of size isn't available, return OutOfMemory (error)
        if (size > self.buffer.len - self.offset) {
            return error.OutOfMemory;
        }

        // Storing current start offset, Changing the offset
        const start = self.offset;
        self.offset += size;

        // Returning the memory (from start to current offset)
        return self.buffer[start..self.offset];
    }

    /// Allocates and return memory of a specific size and alignment.
    pub fn allocAligned(self: *ArenaAllocator, size: usize, alignment: usize) ![]u8 {
        try self.alignOffset(alignment);
        return try self.alloc(size);
    }

    /// Resets the allocator and invalidates all allocations.
    pub fn reset(self: *ArenaAllocator) void {
        self.offset = 0;
    }

    /// Returns the size of available memory.
    pub fn remaining(self: *const ArenaAllocator) usize {
        return self.buffer.len - self.offset;
    }

    /// Returns the size of used memory.
    pub fn used(self: *const ArenaAllocator) usize {
        return self.offset;
    }

    /// Aligns the memory offset by creating padding into the memory.
    fn alignOffset(self: *ArenaAllocator, alignment: usize) !void {
        // Creates a padding using
        const padding = (alignment - (self.offset % alignment)) % alignment;

        // Checks if adding the padding cause memory overflow
        if (padding > self.buffer.len - self.offset) {
            return error.OutOfMemory;
        }

        // Adding the padding to the memory
        self.offset += padding;
    }

    /// Returns a pointer to undefined memory.
    pub fn create(self: *ArenaAllocator, comptime T: type) !*T {
        const memory = try self.allocAligned(@sizeOf(T), @alignOf(T));
        // Casting a *u8 to *T using @ptrCast()
        // The alignment may be different, therefore @alignCast() is used
        // @alignCast assumes that the ptr is aligned
        return @ptrCast(@alignCast(memory.ptr));
    }

    /// Returns an initialized pointer to a type in memory.
    pub fn createInit(self: *ArenaAllocator, comptime T: type, value: T) !*T {
        const object: *T = try self.create(T);
        object.* = value;
        return object;
    }

    /// Returns whether the ArenaAllocator owns the pointer.
    pub fn owns(self: *const ArenaAllocator, ptr: *const anyopaque) bool {
        const addr = @intFromPtr(ptr);
        const start = @intFromPtr(self.buffer.ptr);
        const end = start + self.buffer.len;
        return addr >= start and addr < end;
    }

    /// Allocates space for count instances of T and returns a slice.
    pub fn createMany(self: *ArenaAllocator, comptime T: type, count: usize) ![]T {
        const total_size = try std.math.mul(
            usize,
            @sizeOf(T),
            count,
        );

        const memory = try self.allocAligned(total_size, @alignOf(T));
        const ptr: [*]T = @ptrCast(@alignCast(memory.ptr));
        return ptr[0..count];
    }

    /// Allocates space for count instances of T, initializes them to value, and returns a slice.
    pub fn createManyInit(
        self: *ArenaAllocator,
        comptime T: type,
        count: usize,
        value: T,
    ) ![]T {
        const objects = try self.createMany(T, count);
        for (objects) |*object| object.* = value;
        return objects;
    }
};

test "alloc decreases the remaining size of memory" {
    var buffer: [256]u8 = undefined;
    var arena = ArenaAllocator.init(&buffer);

    _ = try arena.alloc(100);

    try std.testing.expectEqual(arena.remaining(), 156);
}

test "alloc increases the used size of memory" {
    var buffer: [256]u8 = undefined;
    var arena = ArenaAllocator.init(&buffer);

    _ = try arena.alloc(100);
    try std.testing.expectEqual(arena.used(), 100);

    _ = try arena.alloc(20);
    try std.testing.expectEqual(arena.used(), 120);

    _ = try arena.alloc(16);
    try std.testing.expectEqual(arena.used(), 136);
}

test "create returns a pointer to the type" {
    const Player = struct { health: u32, x: f32, y: f32 };

    var buffer: [256]u8 = undefined;
    var arena = ArenaAllocator.init(&buffer);

    const player = try arena.create(Player);

    try std.testing.expectEqual(@TypeOf(player), *Player);
}
