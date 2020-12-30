const sf = @import("sfml");
const std = @import("std");

pub fn main() !void {
    var window = try sf.RenderWindow.init(.{ .x = 200, .y = 200 }, 32, "SFML works!");
    defer window.deinit();

    var shape = try sf.CircleShape.init(100.0);
    defer shape.deinit();
    shape.setFillColor(sf.Color.Green);

    for (morse_table) |t| {
        std.debug.print("{}\n", .{t});
    }

    while (window.isOpen()) {
        while (window.pollEvent()) |event| {
            if (event == .closed)
                window.close();
            
        }

        window.clear(sf.Color.Black);
        window.draw(shape, null);
        window.display();
    }
}


// This array of 256 strings stores a morse code for each ascii character
const morse_table: [256][]const u8 = comptime {
    // We create this table from a file at comptime
    @setEvalBranchQuota(10000); // For more complex comptime evaluations

    // Init the table with just empty strings everywhere
    var table = [1][]const u8{ "" } ** 256;
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
