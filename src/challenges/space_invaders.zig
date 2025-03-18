const std = @import("std");

const utils = @import("utils");
const rl = utils.rl;

//----------------------------------------------------------------------------------
// Consts
//----------------------------------------------------------------------------------

pub const config = .{
    .title = "Space Invaders",
    .enemies = 36,
    .bullets = 64,
    .ship_speed = 150, // pixel per second
    .enemy_speed = 50, // pixels per second
    .bullet_speed = 300, // pixels per second
    .bullet_poll_count = 32,
    .dead_pos = rl.Vector2.init(500, 500),
};

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

pub const State = struct {
    render_texture: rl.RenderTexture2D = undefined,
    boundary: rl.Vector2,
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

const Ship = struct {
    p: rl.Vector2,
    size: rl.Vector2,
    dP: rl.Vector2,

    fn update(self: *Ship, state: *State, dt: f32) void {
        if (rl.isKeyDown(rl.KeyboardKey.w) or rl.isKeyDown(rl.KeyboardKey.up)) {
            self.dP.y -= 1.5;
        } else if (rl.isKeyDown(rl.KeyboardKey.s) or rl.isKeyDown(rl.KeyboardKey.down)) {
            self.dP.y += 1.5;
        }
        if (rl.isKeyDown(rl.KeyboardKey.a) or rl.isKeyDown(rl.KeyboardKey.left)) {
            self.dP.x -= 1.5;
        } else if (rl.isKeyDown(rl.KeyboardKey.d) or rl.isKeyDown(rl.KeyboardKey.right)) {
            self.dP.x += 1.5;
        }

        if (rl.isKeyReleased(rl.KeyboardKey.space)) {
            state.bullet_group.spawn(state, .Enemy, self.p, .{ .x = 0, .y = -1 });
        }

        // NOTE: self.p += normalize(self.dp) * (condif.ship_speed * dt);
        self.p = rl.Vector2.add(self.p, rl.Vector2.scale(rl.Vector2.normalize(self.dP), config.ship_speed * dt));

        self.dP = rl.Vector2.init(0, 0);
    }

    fn draw(self: @This()) void {
        const p = rl.Vector2.subtract(self.p, rl.Vector2.scale(self.size, 0.5));
        rl.drawRectangleV(p, self.size, rl.Color.white);
    }
};

const BulletTag = enum {
    Invalid,
    Enemy,
    Player,
};

const Bullet = struct {
    tag: BulletTag,
    p: rl.Vector2,
    dP: rl.Vector2,

    fn invalidate(self: *Bullet) void {
        self.tag = .Invalid;
        self.p = config.dead_pos;
        self.dP = rl.Vector2.init(0, 0);
    }
};

const BulletGroup = struct {
    fired: [config.bullet_poll_count]?*Bullet, // Note relace with proper polling
    r: f32,

    fn spawn(self: *BulletGroup, state: *State, tag: BulletTag, pos: rl.Vector2, vel: rl.Vector2) void {
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

    fn update(self: *BulletGroup, state: *State, dt: f32) void {
        for (0..self.fired.len) |i| {
            if (self.fired[i]) |bullet| {
                switch (bullet.tag) {
                    .Invalid => return,
                    .Player => {
                        if (rl.checkCollisionCircleRec(bullet.p, self.r, .{
                            .x = state.ship.p.x,
                            .y = state.ship.p.y,
                            .width = state.ship.size.x,
                            .height = state.ship.size.y,
                        })) {
                            bullet.invalidate();
                            self.fired[i] = null;
                            state.status = .Dead;
                        }
                    },
                    .Enemy => {
                        for (0..state.enemy_group.alive.len) |index| {
                            if (state.enemy_group.alive[index]) |enemy| {
                                if (rl.checkCollisionCircleRec(bullet.p, self.r, .{
                                    .x = enemy.p.x + state.enemy_group.offset.x,
                                    .y = enemy.p.y + state.enemy_group.offset.y,
                                    .width = state.enemy_group.size.x,
                                    .height = state.enemy_group.size.y,
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

                // NOTE: bullet.p += normalize(bullet.dp) * (config.bullet_speed * dt);
                bullet.p = rl.Vector2.add(bullet.p, rl.Vector2.scale(rl.Vector2.normalize(bullet.dP), config.bullet_speed * dt));

                if (!rl.checkCollisionPointRec(bullet.p, rl.Rectangle{
                    .x = 0,
                    .y = 0,
                    .width = state.boundary.x,
                    .height = state.boundary.y,
                })) {
                    bullet.invalidate();
                    self.fired[i] = null;
                }
            }
        }
    }

    fn draw(self: @This()) void {
        for (0..self.fired.len) |i| {
            if (self.fired[i]) |bullet| {
                rl.drawCircleV(bullet.p, self.r, rl.Color.gold);
            }
        }
    }
};

const Enemy = struct {
    /// position relative to group offset
    p: rl.Vector2,

    fn invalidate(self: *Enemy) void {
        self.p = config.dead_pos;
    }
};

const EnemyGroup = struct {
    alive: [config.enemies]?*Enemy,
    dP: rl.Vector2,
    offset: rl.Vector2,
    size: rl.Vector2,
    wiggle_room: rl.Vector2,
    fire_timer: f32 = 1,
    timer: f32 = 0,

    fn update(self: *EnemyGroup, state: *State, dt: f32) void {
        if (self.offset.x > self.wiggle_room.x) {
            self.dP.x = -2;
        } else if (self.offset.x <= 0) {
            self.dP.x = 2;
        }

        if (self.offset.y > self.wiggle_room.y) {
            self.dP.y = -1;
        } else if (self.offset.y <= 0) {
            self.dP.y = 1;
        }

        // NOTE: self.offset += normalize(self.dp) * (condif.enemy_speed * dt);
        self.offset = rl.Vector2.add(self.offset, rl.Vector2.scale(rl.Vector2.normalize(self.dP), config.enemy_speed * dt));

        self.timer += dt;
        if (self.timer >= self.fire_timer) {
            self.timer = 0;
            self.fire_timer = utils.randomFloat(0.5, 1);

            // TODO: hacky, change active to be a freelist
            var tries: u32 = 0;
            var random_index: u32 = @intCast(utils.randomInt(0, config.enemies));
            while ((self.alive[@intCast(random_index)] == null) and (tries <= 30)) {
                random_index = @intCast(utils.randomInt(0, config.enemies));
                tries += 1;
            }

            if (tries <= 30) {
                // NOTE: bullet_p = (self.size * 0.5) + self.offset + self.alive[random_index].?.p;
                const bullet_p = rl.Vector2.add(rl.Vector2.scale(self.size, 0.5), rl.Vector2.add(self.offset, self.alive[random_index].?.p));
                state.bullet_group.spawn(state, .Player, bullet_p, .{ .x = 0, .y = 1 });
            }
        }
    }

    fn draw(self: @This()) void {
        for (0..self.alive.len) |i| {
            if (self.alive[i]) |enemy| {
                rl.drawRectangleV(rl.Vector2.add(enemy.p, self.offset), self.size, rl.Color.red);
            }
        }
    }
};

// ---------------------------------------------------------------------------------
// internal functions
//----------------------------------------------------------------------------------

fn reset(state: *State) void {
    const spawn_boundary = rl.Rectangle{
        .x = 5,
        .y = 5,
        .width = state.boundary.x * 0.75,
        .height = state.boundary.y * 0.5,
    };

    state.ship = .{
        .size = rl.Vector2.init(20, 20),
        .p = rl.Vector2.init(state.boundary.x / 2, state.boundary.y - 20),
        .dP = rl.Vector2.init(0, 0),
    };

    state.enemy_group = .{
        .alive = [1]?*Enemy{null} ** config.enemies,
        .dP = .{ .x = 1, .y = 0 },
        .offset = rl.Vector2.init(100, 0),
        .size = rl.Vector2.init(20, 20),
        .wiggle_room = rl.Vector2.init(
            state.boundary.x - spawn_boundary.width,
            state.boundary.y - spawn_boundary.height,
        ),
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
fn initEnemies(state: *State, boundary: rl.Rectangle, padding: i32) void {
    const pad: f32 = @floatFromInt(padding);

    const enemy_group = state.enemy_group;

    const check = (pad + enemy_group.size.x) * (pad + enemy_group.size.y) * config.enemies >= boundary.width * boundary.height;

    if (check) {
        std.debug.print("Count too large: {}\n", .{check});
    }

    const x_count = @divTrunc(boundary.width, pad + enemy_group.size.x); // fill the width
    const y_count = @divTrunc(config.enemies, x_count);

    var i: u32 = 0;
    var y: f32 = 0;
    while (y <= y_count + 1) : (y += 1) { // go one extra to be safe
        var x: f32 = 0;
        while (x < x_count) : (x += 1) {
            if (i < config.enemies) {
                state.enemies[i].p.x = boundary.x + x * (pad + enemy_group.size.x);
                state.enemies[i].p.y = boundary.y + y * (pad + enemy_group.size.y);
                state.enemy_group.alive[i] = &state.enemies[i];
                i += 1;
            } else {
                break;
            }
        }
    }
}

pub fn setup(allocator: std.mem.Allocator, width: i32, height: i32) anyerror!*State {
    const state: *State = try allocator.create(State);

    state.* = State{
        .render_texture = try rl.loadRenderTexture(width, height),
        .boundary = rl.Vector2.init(@floatFromInt(width), @floatFromInt(height)),
        .ship = undefined,
        .bullets = try allocator.alloc(Bullet, config.bullets),
        .enemies = try allocator.alloc(Enemy, config.enemies),
        .enemy_group = undefined,
        .bullet_group = undefined,
        .status = undefined,
    };

    reset(state);

    return state;
}

pub fn update(state: *State) void {
    const dt = rl.getFrameTime();

    if (state.status == .Dead) {
        if (rl.isKeyReleased(rl.KeyboardKey.space)) {
            reset(state);
        }
        return;
    }

    state.ship.update(state, dt);
    state.enemy_group.update(state, dt);
    state.bullet_group.update(state, dt);
}

pub fn render(state: *State) void {
    rl.clearBackground(rl.Color.black);

    if (state.status == .Dead) {
        rl.drawText(
            "Game Over",
            @intFromFloat(state.boundary.x / 2 - 150),
            @intFromFloat(state.boundary.y / 2 - 25),
            50,
            rl.Color.red,
        );
        return;
    }

    state.ship.draw();
    state.enemy_group.draw();
    state.bullet_group.draw();
}

pub fn cleanup(state: *State) void {
    rl.unloadRenderTexture(state.render_texture);
}
