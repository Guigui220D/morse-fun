const sf = @import("sfml");
const std = @import("std");

const allocator = std.heap.page_allocator;

usingnamespace @import("bitqueue.zig");

const BeepState = enum {
    dit,
    dah,
    pause,
};

pub fn main() !void {
    var morse_queue = BitQueue(8).init(allocator);
    defer morse_queue.deinit();

    var pause = true;
    var beep_state: BeepState = .pause;
    var clock = try sf.Clock.init();
    defer clock.deinit();

    var window = try sf.RenderWindow.init(.{ .x = 200, .y = 200 }, 32, "SFML works!");
    defer window.deinit();

    var shape = try sf.CircleShape.init(100.0);
    defer shape.deinit();
    shape.setFillColor(sf.Color.Green);

    while (window.isOpen()) {
        while (window.pollEvent()) |event| {
            switch (event) {
                .closed => window.close(),
                .textEntered => |char| {
                    if (char.unicode >= 128)
                        continue;
                    pause = false;
                    const morse = morse_table[char.unicode];
                    for (morse) |beep| {
                        switch (beep) {
                            '.' => { morse_queue.push(0) catch unreachable; },
                            '_' => { morse_queue.push(1) catch unreachable; },
                            else => unreachable
                        }
                    } 
                },
                else => {}
            }
        }

        window.clear(sf.Color.Black);

        if (!pause) {
            switch (beep_state) {
                .dit => {
                    if (clock.getElapsedTime().asSeconds() > 0.2) {
                        _ = clock.restart();
                        beep_state = .pause;
                    }
                        
                },
                .dah => {
                    if (clock.getElapsedTime().asSeconds() > 0.5) {
                        _ = clock.restart();
                        beep_state = .pause;
                    }
                        
                },
                .pause => {
                    if (clock.getElapsedTime().asSeconds() > 0.15) {
                        _ = clock.restart();

                        var new_state = morse_queue.pop();

                        if (new_state) |new| {
                            beep_state = if (new == 1) .dah else .dit;
                        } else
                            pause = true;
                    }
                }
            }
        }

        if (beep_state != .pause)
            window.draw(shape, null);

        window.display();
    }
}


// This array of 128 strings stores a morse code for each ascii character
const morse_table: [128][]const u8 = comptime {
    // We create this table from a file at comptime
    @setEvalBranchQuota(10000); // For more complex comptime evaluations

    // Init the table with just empty strings everywhere
    var table = [1][]const u8{ "" } ** 128;
    const file = @embedFile("morse_codes.txt");

    var line_iterator = std.mem.tokenize(file, "\n");

    // Iterate over the lines of the file
    while (line_iterator.next()) |line| {
        if (line.len == 0)
            continue;

        // A line is composed of two parts, the morse and then which characters this morse code is for
        var morse_part = true;
        var morse: []const u8 = "";
        // Iterate over the characters of the line
        for (line) |char| {
            if (!std.ascii.isASCII(char) or std.ascii.isCntrl(char))
                continue;

            if (morse_part) {
                switch (char) {
                    '_', '.' => { morse = morse ++ [1]u8{ char }; },
                    ':' => { morse_part = false; },
                    else => compileError("The first part of a line in the morse file must be morse: . or _")
                }
            } else {
                table[char] = morse;
            }
        }
    }

    return table;
};
