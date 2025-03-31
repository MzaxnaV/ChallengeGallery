const std = @import("std");

const utils = @import("utils");
const AppData = utils.AppData;
const DrawAPI = utils.DrawAPI;

const V2 = utils.V2;
const V2I = utils.V2I;

const V2ItoV2 = utils.V2ItoV2;

//----------------------------------------------------------------------------------
// Config and others
//----------------------------------------------------------------------------------

const config = .{
    .scl = 20,
    .delay = 12, // frames per second
};

const scale_v: V2I = @splat(config.scl);
const red = 0xff0000ff; // #ff0000ff

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

const State = struct {
    frame_time: u32 = 0,
    snake: Snake,
    food: Food,
    size: V2I,
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
    p: V2I,
    i: u32 = 0,

    fn draw(self: @This(), api: DrawAPI) void {
        var buff: [32]u8 = [1]u8{0} ** 32;

        const pos: V2 = V2ItoV2(self.p * scale_v);

        api.drawRectangle(
            pos,
            V2ItoV2(scale_v),
            red,
        );

        api.drawText(
            std.fmt.bufPrintZ(buff[0..], "{d}", .{self.i}) catch |err| {
                std.debug.print("Failed to format string: {}\n", .{err});
                return;
            },
            pos,
            config.scl,
            utils.Colours.gold,
        );
    }
};

const Snake = struct {
    p: V2I = .{ 15, 15 },
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

        self.p = self.p + switch (self.dir) {
            .up => V2I{ 0, -1 },
            .down => V2I{ 0, 1 },
            .left => V2I{ -1, 0 },
            .right => V2I{ 1, 0 },
            .none => V2I{ 0, 0 },
        };

        self.p = @mod(self.p, state.size);
    }

    fn draw(self: @This(), api: DrawAPI) void {
        const pos: V2 = V2ItoV2(self.p * scale_v);

        api.drawRectangle(
            pos,
            V2ItoV2(scale_v),
            red,
        );

        for (self.tails[0..self.length]) |tail| {
            tail.draw(api);
        }
    }
};

const Food = struct {
    p: V2I,

    fn draw(self: @This(), api: DrawAPI) void {
        const pos: V2 = V2ItoV2(self.p * scale_v);

        api.drawRectangle(
            pos,
            V2ItoV2(scale_v),
            utils.Colours.white,
        );
    }
};

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

export fn setup(app_data: *AppData, width: i32, height: i32) callconv(.C) void {
    const allocator = app_data.fba.allocator();

    var state: *State = allocator.create(State) catch |err| {
        std.debug.print("Failed to create State: {}\n", .{err});
        return;
    };

    const size_x = @divTrunc(width, config.scl);
    const size_y = @divTrunc(height, config.scl);

    state.* = State{
        .snake = Snake{
            .tails = allocator.alloc(Tail, @intCast(size_x * size_y)) catch |err| {
                std.debug.print("Failed to create Tails: {}\n", .{err});
                return;
            },
        },
        .food = Food{
            .p = utils.randomV(i32, 0, size_x, 0, size_y),
        },
        .size = .{ size_x, size_y },
    };

    for (state.snake.tails[0..]) |*tail| {
        tail.i = 0;
        tail.p = .{ -2, -2 };
    }
}

export fn update(app_data: *const AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));

    const api = app_data.input_api;

    const enter = 257;
    const right = 262;
    const left = 263;
    const down = 264;
    const up = 265;
    const w = 87;
    const a = 65;
    const s = 83;
    const d = 68;

    if (api.isKeyReleased(enter)) {
        state.run = true;
        for (state.snake.tails[0..state.snake.length]) |*tail| {
            tail.i = 0;
            tail.p = .{ -2, -2 };
        }
        state.snake.length = 0;
        state.food.p = utils.randomV(i32, 0, state.size[0], 0, state.size[1]);
    }

    if (!state.run) {
        return;
    }

    state.frame_time += 1;

    if (!state.set_input) {
        if (api.isKeyReleased(w) or api.isKeyReleased(up)) {
            if (state.snake.dir != Direction.down) {
                state.snake.dir = Direction.up;
                state.set_input = true;
            }
        } else if (api.isKeyReleased(s) or api.isKeyReleased(down)) {
            if (state.snake.dir != Direction.up) {
                state.snake.dir = Direction.down;
                state.set_input = true;
            }
        } else if (api.isKeyReleased(a) or api.isKeyReleased(left)) {
            if (state.snake.dir != Direction.right) {
                state.snake.dir = Direction.left;
                state.set_input = true;
            }
        } else if (api.isKeyReleased(d) or api.isKeyReleased(right)) {
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
            if (@reduce(.And, state.snake.p == tail.p)) {
                state.snake.dir = .none;
                state.food.p = utils.randomV(i32, 0, state.size[0], 0, state.size[1]);

                state.run = false;
            }
        }

        if (@reduce(.And, (state.snake.p == state.food.p))) {
            state.snake.tails[state.snake.length].p = state.food.p;
            state.snake.tails[state.snake.length].i = state.snake.length;
            state.snake.length += 1;
            state.food.p = utils.randomV(i32, 0, state.size[0], 0, state.size[1]);
        }
    }
}

export fn render(app_data: *const AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));
    const draw_api = app_data.draw_api;

    draw_api.clearBackground(utils.Colours.bg);

    if (!state.run) {
        draw_api.drawText(
            "Game Over!",
            V2ItoV2(.{
                @divTrunc(state.size[0] * config.scl, 4),
                @divTrunc(state.size[1] * config.scl, 2) - 25,
            }),
            50,
            red,
        );
        return;
    }

    state.food.draw(draw_api);

    state.snake.draw(draw_api);
}

export fn cleanup(app_data: *AppData) callconv(.C) void {
    const allocator = app_data.fba.allocator();
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));

    allocator.free(state.snake.tails);

    allocator.destroy(state);
}
