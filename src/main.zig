const std = @import("std");
const f = @import("./future.zig");

const Counter = struct {
    _i: usize = 0,
    _n: usize = 0,

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

        return .{ .state = f.FutureState.Successful, .result = &a._i };
    }
    pub fn deinit(_: *anyopaque) void {}
};

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    // defer gpa.deinit();

    // const alloc = gpa.allocator();
    std.debug.print("abc\n", .{});

    var c = Counter{ ._n = 5 };

    var fut = c.future();

    while (fut.poll().state == f.FutureState.Pending) {}
    // const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080);

    // var server = try addr.listen(.{ .reuse_address = true, .force_nonblocking = true });
    // defer server.deinit();

    // const conn = try server.accept();
    // defer conn.stream.close();

    // _ = try conn.stream.write("abc");

    // const f = Future{};

    // _ = f;
}
