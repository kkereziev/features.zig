const std = @import("std");
const f = @import("./future.zig");

const AllocType = enum {
    Stack,
    Heap,
};

const MyErr = error{
    Hello,
};

const Counter = struct {
    _i: usize = 0,
    _n: usize = 0,
    _alloc: ?std.mem.Allocator = null,
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

    pub fn poll(self: *anyopaque) anyerror!f.Result {
        var a: *Counter = @ptrCast(@alignCast(self));

        if (a._n > a._i) {
            std.debug.print("{any}\n", .{a._i});

            a._i += 1;

            if (a._i == 15) {
                return MyErr.Hello;
            }

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
            s._alloc.?.destroy(s);
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer {
        const ok = gpa.deinit();

        std.debug.assert(ok == std.heap.Check.ok);
    }

    const alloc = gpa.allocator();

    var c = Counter{ ._n = 5 };

    var fut1 = c.future()
        .then(alloc, myFn)
        .then(alloc, myFn)
        .then(alloc, myFn)
        .catchError(alloc, catchFn);

    defer fut1.deinit();

    while (true) {
        const res1 = try fut1.poll();

        if (res1.state == f.FutureState.Successful) {
            break;
        }
    }
}

fn myFn(alloc: std.mem.Allocator, res: *anyopaque) f.Future {
    std.debug.print("hey\n", .{});
    const y: *usize = @ptrCast(@alignCast(res));

    const innerC = alloc.create(Counter) catch {
        @panic("");
    };

    innerC.* = Counter{
        ._i = y.*,
        ._n = y.* + 5,
        ._alloc = alloc,
        ._metadata = .Heap,
    };

    return innerC.future();
}

fn catchFn(alloc: std.mem.Allocator, err: anyerror) f.Future {
    var d = alloc.create(f.Done) catch {
        @panic("out of memory");
    };

    std.debug.print("{any}\n", .{err});

    d.* = f.Done{ ._alloc = alloc };

    return d.future();
}
