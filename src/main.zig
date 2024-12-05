const std = @import("std");
const ray = @import("raylib.zig");

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

    ray.SetConfigFlags(ray.FLAG_MSAA_4X_HINT | ray.FLAG_VSYNC_HINT);
    ray.InitWindow(width, height, "aim4zig");
    defer ray.CloseWindow();

    // SOUND
    ray.InitAudioDevice();
    defer ray.CloseAudioDevice();

    const hit_sound = ray.LoadSound("res/laser.wav");
    defer ray.UnloadSound(hit_sound);
    const fail_sound = ray.LoadSound("res/explosion.wav");
    defer ray.UnloadSound(fail_sound);

    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 8 }){};
    const allocator = gpa.allocator();
    defer {
        switch (gpa.deinit()) {
            .leak => @panic("leaked memory"),
            else => {},
        }
    }

    var list = std.ArrayList(Circle).init(allocator);
    try list.append(.{ .timeCreated = ray.GetTime(), .pos = .{ .x = 100, .y = 200 } });
    var mousePosition = ray.GetMousePosition();
    var mouseClicked = false;
    // Player state
    var score: u16 = 0;
    var health: u2 = 3;

    while (!ray.WindowShouldClose()) {
        if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
            mouseClicked = true;
            mousePosition = ray.GetMousePosition();
        }
        const time = ray.GetTime();

        if (nextSpawn < time) {
            try list.append(.{ .timeCreated = ray.GetTime(), .pos = .{ .x = rand.intRangeAtMost(i32, spawn_border, width - spawn_border), .y = rand.intRangeAtMost(i32, spawn_border, height - spawn_border) } });

            nextSpawn = time + rand.float(f64) * spaw_time_rng_factor + min_time_spawn;
        }
        // draw
        {
            ray.BeginDrawing();
            defer ray.EndDrawing();

            ray.ClearBackground(ray.WHITE);
            const scoreText = try std.fmt.allocPrintZ(allocator, "Score: {d}", .{score});
            defer allocator.free(scoreText);

            ray.DrawText(scoreText, spawn_border, spawn_border, 25, ray.BLACK);
            ray.DrawText(scoreText, spawn_border, spawn_border, 25, ray.BLACK);

            ray.DrawFPS(width - 100, 10);

            // Health drawing
            for (0..health) |i| {
                ray.DrawCircle(spawn_border / 2 + @as(u16, @intCast(i)) * health_radius * 2, spawn_border / 2, health_radius, ray.RED);
            }

            // Circle drawing
            for (list.items, 0..) |circle, i| {
                if (time - circle.timeCreated >= time_alive) {
                    _ = list.swapRemove(i);
                    health -= 1;
                    ray.PlaySound(fail_sound);
                    if (health < 1) {
                        ray.CloseWindow();
                    }
                    continue;
                }
                const r: f32 = get_radius(time, circle.timeCreated, radius);
                if (mouseClicked) {
                    if (@abs(mousePosition.x - @as(f64, @floatFromInt(circle.pos.x))) < r) {
                        if (@abs(mousePosition.y - @as(f64, @floatFromInt(circle.pos.y))) < r) {
                            _ = list.swapRemove(i);
                            score += 1;
                            ray.PlaySound(hit_sound);
                            continue;
                        }
                    }
                }
                ray.DrawCircle(circle.pos.x, circle.pos.y, r, ray.RED);
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
