/// 
/// Arena Allocator 
/// copyright © github.com/shaheerbits
/// 

const std = @import("std");

pub const ArenaAllocator = struct {
    buffer: []u8,
    offset: usize,

    pub fn init(buffer: []u8) ArenaAllocator {
        return .{
            .buffer = buffer,
            .offset = @as(usize, 0),
        };
    }

    pub fn alloc(self: *ArenaAllocator, size: usize) ![]u8 {
        if (size > self.buffer.len - self.offset) {
            return error.OutOfMemory;
        }

        const start = self.offset;
        self.offset += size;

        return self.buffer[start..self.offset];
    }

    pub fn clear(self: *ArenaAllocator) void {
        self.offset = @as(usize, 0);
    }

    pub fn remaining(self: *const ArenaAllocator) usize {
        return self.buffer.len - self.offset;
    }
};
