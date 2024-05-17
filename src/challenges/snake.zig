const std = @import("std");

const rl = struct {
    usingnamespace @import("raylib");
    usingnamespace @import("raylib-math");
};

const utils = @import("utils");
const Vector2I = utils.Vector2I;

//----------------------------------------------------------------------------------
// Consts
//----------------------------------------------------------------------------------

pub const config = .{
    .title = "Snake",
    .scl = 20,
    .delay = 12, // frames per second
};

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

const Direction = enum {
    none,
    left,
    right,
    up,
    down,
};

const Tail = struct {
    p: Vector2I,
    i: u32 = 0,

    fn draw(self: @This()) void {
        const pos = utils.vector2IScale(self.p, config.scl);

        rl.drawRectangle(
            pos.x,
            pos.y,
            config.scl,
            config.scl,
            rl.Color.red,
        );

        rl.drawText(
            rl.textFormat("%d", .{self.i}),
            pos.x,
            pos.y,
            config.scl,
            rl.Color.gold,
        );
    }
};

const Snake = struct {
    p: Vector2I = Vector2I.init(15, 15),
    dir: Direction = Direction.none,
    tails: []Tail = undefined,
    length: u32 = 0,

    fn update(self: *Snake) void {
        if (self.length > 0) {
            var i = self.length - 1;
            while (i > 0) : (i -= 1) {
                self.tails[i].p = self.tails[i - 1].p;
            }
            self.tails[0].p = self.p;
        }

        self.p = utils.vector2IAdd(self.p, switch (self.dir) {
            .up => .{ .x = 0, .y = -1 },
            .down => .{ .x = 0, .y = 1 },
            .left => .{ .x = -1, .y = 0 },
            .right => .{ .x = 1, .y = 0 },
            .none => .{ .x = 0, .y = 0 },
        });

        self.p.x = @mod(self.p.x, g.size_x);
        self.p.y = @mod(self.p.y, g.size_y);
    }

    fn draw(self: @This()) void {
        const pos = utils.vector2IScale(self.p, config.scl);
        rl.drawRectangle(
            pos.x,
            pos.y,
            config.scl,
            config.scl,
            rl.Color.red,
        );

        for (self.tails[0..self.length]) |tail| {
            tail.draw();
        }
    }
};

const Food = struct {
    p: Vector2I = Vector2I.init(0, 0),

    fn draw(self: @This()) void {
        const pos = utils.vector2IScale(self.p, config.scl);

        rl.drawRectangle(
            pos.x,
            pos.y,
            config.scl,
            config.scl,
            rl.Color.white,
        );
    }
};

//----------------------------------------------------------------------------------
// Globals
//----------------------------------------------------------------------------------

var g: struct {
    render_texture: rl.RenderTexture2D = undefined,
    frame_time: u32 = 0,
    snake: Snake = .{},
    food: Food = .{},
    size_x: i32 = 0,
    size_y: i32 = 0,
    run: bool = true,
    set_input: bool = false,
} = .{};

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

pub fn setup(allocator: std.mem.Allocator, comptime width: comptime_int, comptime height: comptime_int) anyerror!*rl.RenderTexture2D {
    g.render_texture = rl.loadRenderTexture(width, height);

    const size_x = width / config.scl;
    const size_y = height / config.scl;

    g.size_x = size_x;
    g.size_y = size_y;

    g.snake.tails = try allocator.alloc(Tail, size_x * size_y);

    for (g.snake.tails[0..]) |*tail| {
        tail.i = 0;
        tail.p = .{ .x = -2, .y = -2 };
    }

    g.food.p = utils.randomVector2I(0, size_x, 0, size_y);

    return &g.render_texture;
}

pub fn update() void {
    if (rl.isKeyReleased(rl.KeyboardKey.key_enter)) {
        g.run = true;
        for (g.snake.tails[0..g.snake.length]) |*tail| {
            tail.i = 0;
            tail.p = .{ .x = -2, .y = -2 };
        }
        g.snake.length = 0;
        g.food.p = utils.randomVector2I(0, g.size_x, 0, g.size_y);
    }

    if (!g.run) {
        return;
    }

    g.frame_time += 1;

    if (!g.set_input) {
        if (rl.isKeyReleased(rl.KeyboardKey.key_w) or rl.isKeyReleased(rl.KeyboardKey.key_up)) {
            if (g.snake.dir != Direction.down) {
                g.snake.dir = Direction.up;
                g.set_input = true;
            }
        } else if (rl.isKeyReleased(rl.KeyboardKey.key_s) or rl.isKeyReleased(rl.KeyboardKey.key_down)) {
            if (g.snake.dir != Direction.up) {
                g.snake.dir = Direction.down;
                g.set_input = true;
            }
        } else if (rl.isKeyReleased(rl.KeyboardKey.key_a) or rl.isKeyReleased(rl.KeyboardKey.key_left)) {
            if (g.snake.dir != Direction.right) {
                g.snake.dir = Direction.left;
                g.set_input = true;
            }
        } else if (rl.isKeyReleased(rl.KeyboardKey.key_d) or rl.isKeyReleased(rl.KeyboardKey.key_right)) {
            if (g.snake.dir != Direction.left) {
                g.snake.dir = Direction.right;
                g.set_input = true;
            }
        }
    }

    if (g.frame_time > config.delay) {
        g.set_input = false;
        g.frame_time = 0;
        // do update here
        g.snake.update();

        for (g.snake.tails[0..g.snake.length]) |tail| {
            if (utils.isEqual(g.snake.p, tail.p)) {
                g.snake.dir = .none;
                g.food.p = utils.randomVector2I(0, g.size_x, 0, g.size_y);

                g.run = false;
            }
        }

        if (utils.isEqual(g.snake.p, g.food.p)) {
            g.snake.tails[g.snake.length].p = g.food.p;
            g.snake.tails[g.snake.length].i = g.snake.length;
            g.snake.length += 1;
            g.food.p = utils.randomVector2I(0, g.size_x, 0, g.size_y);
        }
    }
}

pub fn render() void {
    rl.clearBackground(rl.Color.black);

    if (!g.run) {
        rl.drawText(
            "Game Over!",
            @divTrunc(g.size_x * config.scl, 4),
            @divTrunc(g.size_y * config.scl, 2) - 25,
            50,
            rl.Color.red,
        );
        return;
    }

    g.food.draw();

    g.snake.draw();
}

pub fn cleanup() void {}
