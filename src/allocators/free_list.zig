//!
//! Free List Allocator
//! copyright © github.com/shaheerbits
//!

const std = @import("std");

/// The struct that defines memory block (used or free)
pub const Block = struct {
    const MIN_BLOCK_SIZE = 16;

    size: usize,
    free: bool,
    next: ?*Block,

    pub fn findFreeBlock(self: *Block, size: usize) ?*Block {
        var current: ?*Block = self;

        while (current) |block| {
            if (block.size >= size and block.free) return block;
            current = block.next;
        }

        // No free block found with required size
        return null;
    }

    /// Returns a pointer to user memory assosiated with this Block.
    pub fn memory(self: *Block) [*]u8 {
        return @ptrFromInt(
            @intFromPtr(self) + @sizeOf(Block),
        );
    }

    /// Returns a pointer to the block headers from a pointer to user memory.
    pub fn fromMemory(ptr: *anyopaque) *Block {
        return @ptrFromInt(
            @intFromPtr(ptr) - @sizeOf(Block),
        );
    }

    /// Returns a boolean representing whether this block can split or not.
    pub fn canSplit(self: *const Block, requested_size: usize) bool {
        return self.size > requested_size + @sizeOf(Block) + MIN_BLOCK_SIZE;
    }

    /// Splits a block in two if block can split.
    /// Returns a pointer to the new block if can split, null otherwise.
    pub fn split(self: *Block, requested_size: usize) ?*Block {
        if (!self.canSplit(requested_size)) return null;

        const block: *Block = @ptrFromInt(
            @intFromPtr(self.memory()) + requested_size,
        );

        block.* = .{
            .size = self.size - requested_size - @sizeOf(Block),
            .free = true,
            .next = self.next,
        };

        self.size = requested_size;
        self.next = block;

        return block;
    }
};

pub const FreeListAllocator = struct {
    const DEFAULT_ALIGNMENT = @alignOf(Block);

    /// The buffer that defines a memory space
    buffer: []u8,
    /// The pointer that defines the first block of memory
    head: *Block,

    /// Initializes a FreeListAllocator. Returns a reference to the allocator.
    pub fn init(
        buffer: []align(DEFAULT_ALIGNMENT) u8,
    ) !FreeListAllocator {
        // If buffer size is less than 24 bytes return error
        if (buffer.len < @sizeOf(Block)) return error.BufferTooSmall;

        // Cast a [*]u8 to *Block
        const head: *Block =
            @ptrCast(@alignCast(buffer.ptr));

        head.* = .{
            // size refers to the size of user memory buffer (headers excluded)
            .size = buffer.len - @sizeOf(Block),
            .free = true,
            .next = null,
        };

        return .{
            .buffer = buffer,
            .head = head,
        };
    }

    /// Aligns the size to match the alignment of memory block
    fn alignForward(value: usize, alignment: usize) usize {
        return (value + alignment - 1) & ~(alignment - 1);
    }

    /// Alocates and return a space in memory buffer.
    pub fn alloc(self: *FreeListAllocator, size: usize) ![]u8 {
        const actual_size = alignForward(size, DEFAULT_ALIGNMENT);

        const block = self.head.findFreeBlock(actual_size) orelse
            return error.OutOfMemory;

        _ = block.split(actual_size);

        block.free = false;

        return block.memory()[0..size];
    }

    /// Marks the memory as free.
    pub fn free(_: *FreeListAllocator, ptr: *anyopaque) void {
        const block = Block.fromMemory(ptr);
        block.free = true;
    }
};
