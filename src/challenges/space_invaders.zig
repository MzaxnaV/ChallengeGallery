const std = @import("std");

const utils = @import("utils");
const AppData = utils.AppData;
const RenderAPI = utils.RenderAPI;
const UpdateAPI = utils.UpdateAPI;

const V2 = utils.V2;

//----------------------------------------------------------------------------------
// Consts
//----------------------------------------------------------------------------------

pub const config = .{
    .enemies = 36,
    .bullets = 64,
    .ship_speed = 150, // pixel per second
    .enemy_speed = 50, // pixels per second
    .bullet_speed = 300, // pixels per second
    .bullet_poll_count = 32,
    .dead_pos = V2{ 500, 500 },
};

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

pub const State = struct {
    boundary: V2,
    ship: Ship,
    bullets: []Bullet,
    bullet_group: BulletGroup,
    enemies: []Enemy,
    enemy_group: EnemyGroup,
    status: enum {
        Alive,
        Dead,
    },
};

fn normalize(vec: V2) V2 {
    var result = V2{ 0, 0 };
    const len = @sqrt(@reduce(.Add, vec * vec));
    if (len > 0) {
        const i_len: V2 = @splat(1 / len);
        result = vec * i_len;
    }

    return result;
}

const Ship = struct {
    p: V2,
    size: V2,
    dP: V2,

    fn update(self: *Ship, api: UpdateAPI, state: *State, dt: f32) void {
        const right = 262;
        const left = 263;
        const down = 264;
        const up = 265;
        const w = 87;
        const a = 65;
        const s = 83;
        const d = 68;
        const space = 32;

        if (api.isKeyDown(w) or api.isKeyDown(up)) {
            self.dP -= .{ 0, 1.5 };
        } else if (api.isKeyDown(s) or api.isKeyDown(down)) {
            self.dP += .{ 0, 1.5 };
        }
        if (api.isKeyDown(a) or api.isKeyDown(left)) {
            self.dP -= .{ 1.5, 0 };
        } else if (api.isKeyDown(d) or api.isKeyDown(right)) {
            self.dP += .{ 1.5, 0 };
        }

        if (api.isKeyReleased(space)) {
            state.bullet_group.spawn(state, .Enemy, self.p, .{ 0, -1 });
        }

        const time_scaled_ship_speed: V2 = @splat(config.ship_speed * dt);
        self.p += normalize(self.dP) * time_scaled_ship_speed;

        self.dP = .{ 0, 0 };
    }

    fn draw(self: @This(), api: RenderAPI) void {
        const p = self.p - (self.size * @as(V2, @splat(0.5)));
        api.drawRectangle(p, self.size, utils.Colours.white);
    }
};

const BulletTag = enum {
    Invalid,
    Enemy,
    Player,
};

const Bullet = struct {
    tag: BulletTag,
    p: V2,
    dP: V2,

    fn invalidate(self: *Bullet) void {
        self.tag = .Invalid;
        self.p = config.dead_pos;
        self.dP = @splat(0);
    }
};

const BulletGroup = struct {
    fired: [config.bullet_poll_count]?*Bullet, // Note relace with proper polling
    r: f32,

    fn spawn(self: *BulletGroup, state: *State, tag: BulletTag, pos: V2, vel: V2) void {
        var index: u32 = 0;
        while (index < state.bullets.len) : (index += 1) {
            const bullet: *Bullet = &state.bullets[index];
            if (bullet.tag == .Invalid) {
                bullet.tag = tag;
                bullet.p = pos;
                bullet.dP = vel;
                break;
            }
        }

        for (0..self.fired.len) |i| {
            if (self.fired[i] == null) {
                self.fired[i] = &state.bullets[index];
                break;
            }
        }
    }

    fn update(self: *BulletGroup, api: UpdateAPI, state: *State, dt: f32) void {
        for (0..self.fired.len) |i| {
            if (self.fired[i]) |bullet| {
                switch (bullet.tag) {
                    .Invalid => return,
                    .Player => {
                        if (api.checkCollisionCircleRec(bullet.p, self.r, .{
                            .p = state.ship.p,
                            .size = state.ship.size,
                        })) {
                            bullet.invalidate();
                            self.fired[i] = null;
                            state.status = .Dead;
                        }
                    },
                    .Enemy => {
                        for (0..state.enemy_group.alive.len) |index| {
                            if (state.enemy_group.alive[index]) |enemy| {
                                if (api.checkCollisionCircleRec(bullet.p, self.r, .{
                                    .p = enemy.p + state.enemy_group.offset,
                                    .size = state.enemy_group.size,
                                })) {
                                    enemy.invalidate();
                                    state.enemy_group.alive[index] = null;
                                    bullet.invalidate();
                                    self.fired[i] = null;
                                }
                            }
                        }
                    },
                }

                const time_scaled_bullet_speed: V2 = @splat(config.bullet_speed * dt);
                bullet.p += normalize(bullet.dP) * time_scaled_bullet_speed;

                if (!api.checkCollisionPointRec(bullet.p, .{
                    .p = .{ 0, 0 },
                    .size = state.boundary,
                })) {
                    bullet.invalidate();
                    self.fired[i] = null;
                }
            }
        }
    }

    fn draw(self: @This(), api: RenderAPI) void {
        for (0..self.fired.len) |i| {
            if (self.fired[i]) |bullet| {
                api.drawCircle(bullet.p, self.r, utils.Colours.gold);
            }
        }
    }
};

const Enemy = struct {
    /// position relative to group offset
    p: V2,

    fn invalidate(self: *Enemy) void {
        self.p = config.dead_pos;
    }
};

const EnemyGroup = struct {
    alive: [config.enemies]?*Enemy,
    dP: V2,
    offset: V2,
    size: V2,
    wiggle_room: V2,
    fire_timer: f32 = 1,
    timer: f32 = 0,

    fn update(self: *EnemyGroup, state: *State, dt: f32) void {
        if (self.offset[0] > self.wiggle_room[0]) {
            self.dP[0] = -2;
        } else if (self.offset[0] <= 0) {
            self.dP[0] = 2;
        }

        if (self.offset[1] > self.wiggle_room[1]) {
            self.dP[1] = -1;
        } else if (self.offset[1] <= 0) {
            self.dP[1] = 1;
        }

        const time_scaled_enemy_speed: V2 = @splat(config.enemy_speed * dt);
        self.offset += normalize(self.dP) * time_scaled_enemy_speed;

        self.timer += dt;
        if (self.timer >= self.fire_timer) {
            self.timer = 0;
            self.fire_timer = utils.randomFloat(0.5, 1);

            // TODO: hacky, change active to be a freelist
            var tries: u32 = 0;
            const max_tries = 30;
            var random_index: u32 = utils.randomInt(u32, 0, config.enemies);
            while ((self.alive[@intCast(random_index)] == null) and (tries <= max_tries)) {
                random_index = utils.randomInt(u32, 0, config.enemies);
                tries += 1;
            }

            if (tries <= max_tries) {
                const half: V2 = @splat(0.5);
                const bullet_p = self.size + half + self.offset + self.alive[random_index].?.p;
                state.bullet_group.spawn(state, .Player, bullet_p, .{ 0, 1 });
            }
        }
    }

    fn draw(self: @This(), api: RenderAPI) void {
        for (0..self.alive.len) |i| {
            if (self.alive[i]) |enemy| {
                const red = 0xff0000ff;
                api.drawRectangle(enemy.p + self.offset, self.size, red);
            }
        }
    }
};

// ---------------------------------------------------------------------------------
// internal functions
//----------------------------------------------------------------------------------

fn reset(state: *State) void {
    const spawn_boundary = utils.Rect{
        .p = .{ 5, 5 },
        .size = state.boundary * V2{ 0.75, 0.5 },
    };

    state.ship = .{
        .size = .{ 20, 20 },
        .p = .{ state.boundary[0] / 2, state.boundary[1] - 20 },
        .dP = .{ 0, 0 },
    };

    state.enemy_group = .{
        .alive = [1]?*Enemy{null} ** config.enemies,
        .dP = .{ 1, 0 },
        .offset = V2{ 100, 0 },
        .size = V2{ 20, 20 },
        .wiggle_room = state.boundary - spawn_boundary.size,
    };

    state.bullet_group = .{
        .fired = [1]?*Bullet{null} ** config.bullet_poll_count,
        .r = 4,
    };

    state.status = .Alive;

    for (state.bullets) |*bullet| {
        bullet.invalidate();
    }

    initEnemies(state, spawn_boundary, 5);

    return;
}

// ---------------------------------------------------------------------------------
// App api functions
//----------------------------------------------------------------------------------

/// assumes `boundary` is inside view area, TODO: refactor this
fn initEnemies(state: *State, boundary: utils.Rect, padding: i32) void {
    const pad: V2 = @splat(@as(f32, @floatFromInt(padding)));

    const enemy_group = state.enemy_group;

    const check = @reduce(.Mul, pad + enemy_group.size) * config.enemies >= @reduce(.Mul, boundary.size);

    if (check) {
        std.debug.print("Count too large: {}\n", .{check});
    }

    const x_count = @divTrunc(boundary.size[0], pad[0] + enemy_group.size[0]); // fill the width
    const y_count = @divTrunc(config.enemies, x_count);

    var i: u32 = 0;
    var y: f32 = 0;
    while (y <= y_count + 1) : (y += 1) { // go one extra to be safe
        var x: f32 = 0;
        while (x < x_count) : (x += 1) {
            if (i < config.enemies) {
                state.enemies[i].p = boundary.p + V2{ x, y } * (pad + enemy_group.size);
                state.enemy_group.alive[i] = &state.enemies[i];
                i += 1;
            } else {
                break;
            }
        }
    }
}

export fn setup(app_data: *AppData, width: i32, height: i32) callconv(.C) void {
    const allocator = app_data.fba.allocator();
    const state: *State = allocator.create(State) catch |err| {
        std.debug.print("Failed to create State: {}\n", .{err});
        return;
    };

    state.* = State{
        .boundary = V2{ @floatFromInt(width), @floatFromInt(height) },
        .ship = undefined,
        .bullets = allocator.alloc(Bullet, config.bullets) catch |err| {
            std.debug.print("Failed to create bullets: {}\n", .{err});
            return;
        },
        .enemies = allocator.alloc(Enemy, config.enemies) catch |err| {
            std.debug.print("Failed to create enemies: {}\n", .{err});
            return;
        },
        .enemy_group = undefined,
        .bullet_group = undefined,
        .status = undefined,
    };

    reset(state);
}

export fn update(app_data: *const AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));
    const api = app_data.input_api;
    const space = 32;

    const dt = api.getFrameTime();

    if (state.status == .Dead) {
        if (api.isKeyReleased(space)) {
            reset(state);
        }
        return;
    }

    state.ship.update(api, state, dt);
    state.enemy_group.update(state, dt);
    state.bullet_group.update(api, state, dt);
}

export fn render(app_data: *const AppData) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));
    const api = app_data.draw_api;

    const red = 0xff0000ff;

    api.clearBackground(utils.Colours.black);

    if (state.status == .Dead) {
        api.drawText(
            "Game Over",
            .{ (state.boundary[0] / 2 - 150), (state.boundary[1] / 2 - 25) },
            50,
            red,
        );
        return;
    }

    state.ship.draw(api);
    state.enemy_group.draw(api);
    state.bullet_group.draw(api);
}

export fn cleanup(app_data: *AppData) callconv(.C) void {
    const allocator = app_data.fba.allocator();
    const state: *State = @alignCast(@ptrCast(app_data.fba.buffer.ptr));

    allocator.destroy(state);
}
