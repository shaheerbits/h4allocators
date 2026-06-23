//!
//! h4allocators
//! copyright © github.com/shaheerbits
//!

const std = @import("std");
const allocators = @import("allocators/index.zig");

// const arena_allocator = allocators.arena_allocator;
const free_list_allocator = allocators.free_list_allocator;
const Block = allocators.Block;

pub fn main() !void {
    var buffer: [1024]u8 align(8) = undefined;
    var free_list = try free_list_allocator.init(&buffer);

    const memory = try free_list.alloc(80);
    _ = memory;

    var temp: ?*Block = free_list.head;

    while (temp) |block| {
        std.debug.print("{any}->\n", .{block});
        temp = block.next;
    }

    std.debug.print("null\n", .{});
}
