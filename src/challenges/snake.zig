const std = @import("std");

const rl = struct {
    usingnamespace @import("raylib");
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

pub const State = struct {
    render_texture: rl.RenderTexture2D,
    frame_time: u32 = 0,
    snake: Snake,
    food: Food,
    size_x: i32,
    size_y: i32,
    run: bool = true,
    set_input: bool = false,
};

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
    tails: []Tail,
    length: u32 = 0,

    fn update(self: *Snake, state: *State) void {
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

        self.p.x = @mod(self.p.x, state.size_x);
        self.p.y = @mod(self.p.y, state.size_y);
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
    p: Vector2I,

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

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

pub fn setup(allocator: std.mem.Allocator, width: i32, height: i32) anyerror!*State {
    var state: *State = try allocator.create(State);

    const size_x = @divTrunc(width, config.scl);
    const size_y = @divTrunc(height, config.scl);

    state.* = State{
        .render_texture = rl.loadRenderTexture(width, height),
        .snake = Snake{
            .tails = try allocator.alloc(Tail, @intCast(size_x * size_y)),
        },
        .food = Food{
            .p = utils.randomVector2I(0, size_x, 0, size_y),
        },
        .size_x = size_x,
        .size_y = size_y,
    };

    for (state.snake.tails[0..]) |*tail| {
        tail.i = 0;
        tail.p = .{ .x = -2, .y = -2 };
    }

    return state;
}

pub fn update(state: *State) void {
    if (rl.isKeyReleased(rl.KeyboardKey.key_enter)) {
        state.run = true;
        for (state.snake.tails[0..state.snake.length]) |*tail| {
            tail.i = 0;
            tail.p = .{ .x = -2, .y = -2 };
        }
        state.snake.length = 0;
        state.food.p = utils.randomVector2I(0, state.size_x, 0, state.size_y);
    }

    if (!state.run) {
        return;
    }

    state.frame_time += 1;

    if (!state.set_input) {
        if (rl.isKeyReleased(rl.KeyboardKey.key_w) or rl.isKeyReleased(rl.KeyboardKey.key_up)) {
            if (state.snake.dir != Direction.down) {
                state.snake.dir = Direction.up;
                state.set_input = true;
            }
        } else if (rl.isKeyReleased(rl.KeyboardKey.key_s) or rl.isKeyReleased(rl.KeyboardKey.key_down)) {
            if (state.snake.dir != Direction.up) {
                state.snake.dir = Direction.down;
                state.set_input = true;
            }
        } else if (rl.isKeyReleased(rl.KeyboardKey.key_a) or rl.isKeyReleased(rl.KeyboardKey.key_left)) {
            if (state.snake.dir != Direction.right) {
                state.snake.dir = Direction.left;
                state.set_input = true;
            }
        } else if (rl.isKeyReleased(rl.KeyboardKey.key_d) or rl.isKeyReleased(rl.KeyboardKey.key_right)) {
            if (state.snake.dir != Direction.left) {
                state.snake.dir = Direction.right;
                state.set_input = true;
            }
        }
    }

    if (state.frame_time > config.delay) {
        state.set_input = false;
        state.frame_time = 0;
        // do update here
        state.snake.update(state);

        for (state.snake.tails[0..state.snake.length]) |tail| {
            if (utils.isEqual(state.snake.p, tail.p)) {
                state.snake.dir = .none;
                state.food.p = utils.randomVector2I(0, state.size_x, 0, state.size_y);

                state.run = false;
            }
        }

        if (utils.isEqual(state.snake.p, state.food.p)) {
            state.snake.tails[state.snake.length].p = state.food.p;
            state.snake.tails[state.snake.length].i = state.snake.length;
            state.snake.length += 1;
            state.food.p = utils.randomVector2I(0, state.size_x, 0, state.size_y);
        }
    }
}

pub fn render(state: *State) void {
    rl.clearBackground(rl.Color.black);

    if (!state.run) {
        rl.drawText(
            "Game Over!",
            @divTrunc(state.size_x * config.scl, 4),
            @divTrunc(state.size_y * config.scl, 2) - 25,
            50,
            rl.Color.red,
        );
        return;
    }

    state.food.draw();

    state.snake.draw();
}

pub fn cleanup(state: *State) void {
    rl.unloadRenderTexture(state.render_texture);
}
