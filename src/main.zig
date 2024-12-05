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
    ray.InitWindow(width, height, "zig raylib example");
    defer ray.CloseWindow();

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

            ray.DrawFPS(width - 100, 10);
            for (list.items, 0..) |circle, i| {
                if (time - circle.timeCreated >= time_alive) {
                    _ = list.swapRemove(i);
                    continue;
                }
                const r: f32 = get_radius(time, circle.timeCreated, radius);
                if (mouseClicked) {
                    if (@abs(mousePosition.x - @as(f64, @floatFromInt(circle.pos.x))) < r) {
                        if (@abs(mousePosition.y - @as(f64, @floatFromInt(circle.pos.y))) < r) {
                            _ = list.swapRemove(i);
                            continue;
                        }
                    }
                }
                std.log.debug("{d} {d} {d}\n", .{ time, circle.timeCreated, r });
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
