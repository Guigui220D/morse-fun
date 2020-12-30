//! A managed bit queue. 

const std = @import("std");

// BitQueue template, the bit_group_size argument is for knowing how bits many bits should be grouped when pushed on the actual queue
pub fn BitQueue(comptime bit_group_size: usize) type {
    return struct {
        const Self = @This();   // Self is just a shorter name for BitQueue
        const GroupQueue = std.TailQueue(BitGroup);
        const BitGroup = @Type(.{ 
            .Int = .{ 
                .is_signed = false, 
                .bits = bit_group_size
            }
        }); //An unsigned int for groups of bits to be stored in the queue
        const ShiftU = @Type(.{ 
            .Int = .{ 
                .is_signed = false, 
                .bits = @floatToInt(usize, @log2(@as(f32, bit_group_size)))
            }
        }); //Weird thing to get an unsigned type that can be used to bitshift variables of the BitGroup type

        ///Inits this queue with an allocator
        pub fn init(alloc: *std.mem.Allocator) Self {
            return Self {
                .allocator = alloc,
                .group_queue = .{},
                .group_in = 0,
                .group_in_bit = 0,
                .group_out = 0,
                .group_out_bit = 0
            };
        }
        ///Deinits this queue, destroying the allocated bitgroups
        pub fn deinit(self: *Self) void {
            while (self.group_queue.pop()) |node| {
                self.allocator.destroy(node);
            }
        }

        ///Push a single bit in the queue
        pub fn push(self: *Self, bit: u1) !void {
            self.group_in |= (@intCast(BitGroup, bit) << self.group_in_bit);

            if (self.group_in_bit == @bitSizeOf(BitGroup) - 1) {
                var node = try self.allocator.create(GroupQueue.Node);
                node.data = self.group_in;

                self.group_queue.append(node);

                self.group_in_bit = 0;
                self.group_in = 0;
            } else
                self.group_in_bit += 1;
        }
        ///Push a bunch of bits
        pub fn pushSome(self: *Self, bits: anytype) !void {
            var i: usize = 0;
            var to_push = bits;
            while (i < @bitSizeOf(@TypeOf(bits))) : (i += 1) {
                try self.push(@truncate(u1, to_push & 1));
                to_push >>= 1;
            }
        }

        ///Pop a single bit from the queue
        pub fn pop(self: *Self) ?u1 {
            if (self.group_out_bit == 0) {
                var popped = self.group_queue.popFirst();

                if (popped) |node| {
                    defer self.allocator.destroy(node);

                    self.group_out = node.data;
                    self.group_out_bit = @bitSizeOf(BitGroup) - 1;

                    defer self.group_out >>= 1;
                    return @truncate(u1, self.group_out & 1);
                } else {
                    self.group_out = self.group_in;
                    self.group_out_bit = self.group_in_bit;
                    self.group_in = 0;
                    self.group_in_bit = 0;
                    
                    if (self.group_out_bit != 0) {
                        defer self.group_out >>= 1;
                        defer self.group_out_bit -= 1;
                        return @truncate(u1, self.group_out & 1);
                    } else
                        return null;
                }
            } else {
                defer self.group_out >>= 1;
                defer self.group_out_bit -= 1;
                return @truncate(u1, self.group_out & 1);
            }
        }
        ///Pop a bunch of bits from the queue
        pub fn popSome(self: *Self, comptime T: type) ?T {
            var i: usize = 0;
            var popped: T = 0;
            while (i < @bitSizeOf(T)) : (i += 1) {
                popped <<= 1;
                popped |= self.pop() orelse return null;
            }
            return @bitReverse(T, popped);
        }

        allocator: *std.mem.Allocator,
        group_queue: GroupQueue,
        group_in: BitGroup,
        group_in_bit: ShiftU,
        group_out: BitGroup,
        group_out_bit: ShiftU
    };
}

usingnamespace std.testing;

test "bitqueue" {
    inline for ([_]usize{ 2, 8, 16, 32 }) |bit_group_size| {
        std.debug.print("Testing for {} bits bit groups...\n", .{bit_group_size});

        var bq = BitQueue(bit_group_size).init(std.heap.page_allocator);
        defer bq.deinit();

        try bq.push(1);
        expectEqual(@as(?u1, 1), bq.pop());
        expectEqual(@as(?u1, null), bq.pop());

        try bq.push(1);
        try bq.push(1);
        try bq.push(0);
        expectEqual(@as(?u1, 1), bq.pop());
        expectEqual(@as(?u1, 1), bq.pop());
        expectEqual(@as(?u1, 0), bq.pop());
        expectEqual(@as(?u1, null), bq.pop());

        var thing: u41 = 0b1_10110100_01010111_11000101_10111010_00000001;
        try bq.pushSome(thing);
        var pop: u41 = bq.popSome(u41) orelse std.debug.panic("Couldnt pop the 41 bits", .{});

        expectEqual(thing, pop);

        var thing2: u22 = 0b1001111000101011000110;
        try bq.pushSome(thing2);
        try bq.pushSome(@as(u3, 0b111));

        var pop2 = bq.popSome(u15) orelse std.debug.panic("Couldnt pop the 15 bits", .{});
        var pop3 = bq.popSome(u10) orelse std.debug.panic("Couldnt pop the 10 bits", .{});

        expectEqual(@as(u15, 0b000101011000110), pop2);
        expectEqual(@as(u10, 0b1111001111), pop3);

        expectEqual(@as(?u1, null), bq.pop());
    }
}
