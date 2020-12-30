
const std =  @import("std");

pub const BitQueue = struct {
    const Self = @This();   // Self is just a shorter name for BitQueue
    const ByteQueue = std.TailQueue(u8);

    pub fn init(alloc: *std.mem.Allocator) Self {
        return Self {
            .allocator = alloc,
            .byte_queue = .{},
            .byte_in = 0,
            .byte_in_bit = 0,
            .byte_out = 0,
            .byte_out_bit = 0
        };
    }

    pub fn deinit(self: *Self) void {
        while (self.byte_queue.pop()) |node| {
            self.allocator.destroy(node);
        }
    }

    pub fn push(self: *Self, bit: u1) !void {
        self.byte_in |= (@intCast(u8, bit) << self.byte_in_bit);

        if (self.byte_in_bit == 7) {
            var node = try self.allocator.create(ByteQueue.Node);
            node.data = self.byte_in;

            self.byte_queue.append(node);

            self.byte_in_bit = 0;
            self.byte_in = 0;
        } else
            self.byte_in_bit += 1;
    }

    pub fn pushSome(self: *Self, bits: anytype) !void {
        var i: usize = 0;
        var b = bits;
        while (i < @bitSizeOf(@TypeOf(bits))) : (i += 1) {
            try self.push(@truncate(u1, b & 1));
            b >>= 1;
        }
    }

    pub fn pop(self: *Self) ?u1 {
        if (self.byte_out_bit == 0) {
            var popped = self.byte_queue.popFirst();

            if (popped) |node| {
                defer self.allocator.destroy(node);

                self.byte_out = node.data;
                self.byte_out_bit = 7;

                defer self.byte_out >>= 1;
                return @truncate(u1, self.byte_out & 1);
            } else {
                self.byte_out = self.byte_in;
                self.byte_out_bit = self.byte_in_bit;
                self.byte_in = 0;
                self.byte_in_bit = 0;
                
                if (self.byte_out_bit != 0) {
                    defer self.byte_out >>= 1;
                    defer self.byte_out_bit -= 1;
                    return @truncate(u1, self.byte_out & 1);
                } else
                    return null;
            }
        } else {
            defer self.byte_out >>= 1;
            defer self.byte_out_bit -= 1;
            return @truncate(u1, self.byte_out & 1);
        }
    }

    pub fn popSome(self: *Self, comptime T: type) ?T {
        var i: usize = 0;
        var b: T = 0;
        while (i < @bitSizeOf(T)) : (i += 1) {
            b <<= 1;
            b |= self.pop() orelse return null;
        }
        return @bitReverse(T, b);
    }

    allocator: *std.mem.Allocator,
    byte_queue: ByteQueue,
    byte_in: u8,
    byte_in_bit: u3,
    byte_out: u8,
    byte_out_bit: u3
};

usingnamespace std.testing;

test "bitqueue" {
    var bq = BitQueue.init(std.heap.page_allocator);
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
}
