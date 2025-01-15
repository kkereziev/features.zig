const std = @import("std");

pub const Result = struct {
    result: ?*anyopaque,
    state: FutureState,
};

pub const FutureState = enum {
    Pending,
    Successful,
    Rejected,
};

pub const Future = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        poll: *const fn (*anyopaque) anyerror!Result,
        deinit: *const fn (*anyopaque) void,
    };

    pub fn poll(self: Future) !Result {
        return self.vtable.poll(self.ptr);
    }

    pub fn deinit(self: Future) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn then(self: Future, alloc: std.mem.Allocator, thenFn: *const fn (alloc: std.mem.Allocator, res: *anyopaque) Future) Future {
        const f = alloc.create(Then) catch {
            @panic("out of memory");
        };

        f.* = Then{
            ._left = self,
            ._thenFn = thenFn,
            ._alloc = alloc,
        };

        return f.future();
    }
};

pub const Then = struct {
    _left: ?Future,
    _right: ?Future = null,
    _thenFn: *const fn (alloc: std.mem.Allocator, res: *anyopaque) Future,
    _alloc: std.mem.Allocator,

    pub fn future(self: *Then) Future {
        return .{
            .ptr = self,
            .vtable = &.{
                .poll = poll,
                .deinit = deinit,
            },
        };
    }

    pub fn poll(self: *anyopaque) anyerror!Result {
        var s: *Then = @ptrCast(@alignCast(self));

        if (s._left) |l| {
            const res = try l.poll();

            if (res.state == FutureState.Successful) {
                s._right = s._thenFn(s._alloc, res.result.?);

                s._left = null;

                l.deinit();

                return .{ .state = FutureState.Pending, .result = null };
            }

            return res;
        }

        std.debug.assert(s._left == null);

        return s._right.?.poll();
    }

    pub fn deinit(val: *anyopaque) void {
        const self: *Then = @ptrCast(@alignCast(val));

        if (self._left) |v| {
            v.deinit();
        }

        if (self._right) |v| {
            v.deinit();
        }

        self._alloc.destroy(self);
    }
};
