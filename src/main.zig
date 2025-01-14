const std = @import("std");
const f = @import("./future.zig");

const AllocType = enum {
    Stack,
    Heap,
};

const Counter = struct {
    _i: usize = 0,
    _n: usize = 0,
    _metadata: AllocType = AllocType.Stack,

    pub fn future(self: *Counter) f.Future {
        return .{
            .ptr = self,
            .vtable = &.{
                .poll = poll,
                .deinit = deinit,
            },
        };
    }

    pub fn poll(self: *anyopaque) f.Result {
        var a: *Counter = @ptrCast(@alignCast(self));

        if (a._n > a._i) {
            std.debug.print("{any}\n", .{a._i});

            a._i += 1;

            return .{
                .state = f.FutureState.Pending,
                .result = null,
            };
        }

        return .{
            .state = f.FutureState.Successful,
            .result = &a._i,
        };
    }

    pub fn deinit(self: *anyopaque) void {
        const s: *Counter = @ptrCast(@alignCast(self));

        if (s._metadata == .Heap) {
            std.heap.page_allocator.destroy(s);
        }
    }

    pub fn then(res: *anyopaque) f.Future {
        const c = std.heap.page_allocator.create(Counter) catch {
            //todo: handle with reject
            @panic("abc");
        };

        const i: *usize = @ptrCast(@alignCast(res));

        c.* = Counter{
            ._i = i.*,
            ._n = i.* + 5,
            ._metadata = AllocType.Heap,
        };

        return c.future();
    }
};

pub fn main() !void {
    var c = Counter{ ._n = 5 };
    var c2 = Counter{ ._n = 20, ._i = 15 };

    var t = f.Then{
        ._left = c.future(),
        ._thenFn = myFn,
    };

    var t2 = f.Then{
        ._left = c2.future(),
        ._thenFn = myFn,
    };

    var fut1 = t.future();
    defer fut1.deinit();

    var fut2 = t2.future();
    defer fut2.deinit();

    while (true) {
        const res1 = fut1.poll();
        const res2 = fut2.poll();

        if (res1.state == f.FutureState.Successful and res2.state == f.FutureState.Successful) {
            break;
        }
    }
    // const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080);

    // var server = try addr.listen(.{ .reuse_address = true, .force_nonblocking = true });
    // defer server.deinit();

    // const conn = try server.accept();
    // defer conn.stream.close();

    // _ = try conn.stream.write("abc");

    // const f = Future{};

    // _ = f;
}

fn myFn(res: *anyopaque) f.Future {
    std.debug.print("hey\n", .{});
    const y: *usize = @ptrCast(@alignCast(res));

    const innerC = std.heap.page_allocator.create(Counter) catch {
        @panic("");
    };

    innerC.* = Counter{
        ._i = y.*,
        ._n = y.* + 5,
    };

    return innerC.future();
}
