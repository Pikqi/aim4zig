const std = @import("std");
const ray = @import("raylib");

pub fn main() !void {
    try ray_main();
}

const Position = struct {
    x: i32,
    y: i32,
};

const radius = 50;
const health_radius = 20;
const time_alive = 4;
const min_time_spawn = 0.2;
const spaw_time_rng_factor = 0.3;
const spawn_border = 50;
const max_health = 3;

const list_capacity = 20;

const Circle = struct {
    pos: Position,
    timeCreated: f64,
};

var nextSpawn: f64 = 0;
fn ray_main() !void {

    // RNG
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    // const monitor = ray.GetCurrentMonitor();
    // const width = ray.GetMonitorWidth(monitor);
    // const height = ray.GetMonitorHeight(monitor);
    const width = 800;
    const height = 450;

    ray.setConfigFlags(ray.ConfigFlags{ .msaa_4x_hint = true, .vsync_hint = true });
    ray.initWindow(width, height, "aim4zig");
    defer ray.closeWindow();

    // SOUND
    ray.initAudioDevice();
    defer ray.closeAudioDevice();

    const hit_sound = ray.loadSound("res/laser.wav");
    defer ray.unloadSound(hit_sound);
    const fail_sound = ray.loadSound("res/explosion.wav");
    defer ray.unloadSound(fail_sound);

    // var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 8 }){};
    // const allocator = gpa.allocator();
    var buffer: [2048]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    // defer {
    //     switch (gpa.deinit()) {
    //         .leak => @panic("leaked memory"),
    //         else => {},
    //     }
    // }

    var list = try std.ArrayList(Circle).initCapacity(allocator, list_capacity);
    var mousePosition = ray.getMousePosition();
    var mouseClicked = false;
    // Player state
    var score: u16 = 0;
    var health: u2 = max_health;
    var gameStarted: bool = false;
    var gameOver: bool = false;

    while (!ray.windowShouldClose()) {
        mouseClicked = false;
        if (ray.isMouseButtonPressed(ray.MouseButton.mouse_button_left)) {
            mouseClicked = true;
            mousePosition = ray.getMousePosition();
        }
        const time = ray.getTime();

        if (nextSpawn < time and !gameOver and gameStarted) {
            try list.append(.{ .timeCreated = ray.getTime(), .pos = .{ .x = rand.intRangeAtMost(i32, spawn_border, width - spawn_border), .y = rand.intRangeAtMost(i32, spawn_border, height - spawn_border) } });

            nextSpawn = time + rand.float(f64) * spaw_time_rng_factor + min_time_spawn;
        }
        // draw
        {
            ray.beginDrawing();
            defer ray.endDrawing();

            ray.clearBackground(ray.Color.white);

            if (!gameStarted) {
                ray.drawText("Click to start", spawn_border, spawn_border, 25, ray.Color.black);
                if (mouseClicked) {
                    gameStarted = true;
                    health = max_health;
                }
                continue;
            }
            if (gameOver) {
                const gameOverText = try std.fmt.allocPrintZ(allocator, "Your score was: {d}, try again?", .{score});
                ray.drawText(gameOverText, spawn_border, spawn_border, 25, ray.Color.black);
                allocator.free(gameOverText);
                if (mouseClicked) {
                    gameOver = false;
                    health = max_health;
                    score = 0;
                }
                continue;
            }

            const scoreText = try std.fmt.allocPrintZ(allocator, "Score: {d}", .{score});

            ray.drawText(scoreText, spawn_border, spawn_border, 25, ray.Color.black);
            allocator.free(scoreText);

            ray.drawFPS(width - 100, 10);

            // Health drawing
            for (0..health) |i| {
                ray.drawCircle(spawn_border / 2 + @as(u16, @intCast(i)) * health_radius * 2, spawn_border / 2, health_radius, ray.Color.red);
            }

            // Circle drawing
            for (list.items, 0..) |circle, i| {
                if (time - circle.timeCreated >= time_alive) {
                    _ = list.swapRemove(i);
                    health -= 1;
                    ray.playSound(fail_sound);
                    if (health < 1) {
                        list.clearRetainingCapacity();
                        gameOver = true;
                        break;
                    }
                    continue;
                }
                const r: f32 = get_radius(time, circle.timeCreated, radius);
                if (mouseClicked) {
                    if (@abs(mousePosition.x - @as(f64, @floatFromInt(circle.pos.x))) < r) {
                        if (@abs(mousePosition.y - @as(f64, @floatFromInt(circle.pos.y))) < r) {
                            _ = list.swapRemove(i);
                            score += 1;
                            ray.playSound(hit_sound);
                            continue;
                        }
                    }
                }
                ray.drawCircle(circle.pos.x, circle.pos.y, r, ray.Color.orange);
            }
        }
    }
}

fn get_radius(currTime: f64, timeCreated: f64, maxRadius: comptime_int) f32 {
    const asc: bool = currTime - timeCreated < time_alive / 2;
    if (asc) {
        return @as(f32, @floatCast((currTime - timeCreated) / @as(f32, @floatFromInt(time_alive / 2)))) * maxRadius;
    }
    return @as(f32, @floatFromInt(time_alive / 2)) / @as(f32, @floatCast((currTime - timeCreated))) * maxRadius;
}
