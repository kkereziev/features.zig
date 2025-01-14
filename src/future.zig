const std = @import("std");

// const ThenFn = fn (comptime T: type) T;

const AllocType = enum {
    Stack,
    Heap,
};

pub const FutureState = enum {
    Pending,
    Successful,
    Rejected,
};

pub const Result = struct {
    result: ?*anyopaque,
    state: FutureState,
};

const VTable = struct {
    poll: *const fn (*anyopaque) Result,
    deinit: *const fn (*anyopaque) void,
};

pub const Future = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub fn poll(self: Future) Result {
        return self.vtable.poll(self.ptr);
    }

    pub fn deinit(self: Future) void {
        self.vtable.deinit(self.ptr);
    }
};

pub const Then = struct {
    _left: ?Future,
    _right: ?Future = null,
    _thenFn: *const fn (res: *anyopaque) Future,

    pub fn init(f: Future, thenFn: *const fn (res: *anyopaque) Future) Then {
        return .{
            ._left = f,
            ._thenFn = thenFn,
        };
    }

    pub fn future(self: *Then) Future {
        return .{
            .ptr = self,
            .vtable = &.{
                .poll = poll,
                .deinit = deinit,
            },
        };
    }

    pub fn poll(self: *anyopaque) Result {
        var s: *Then = @ptrCast(@alignCast(self));

        if (s._left) |l| {
            const res = l.poll();

            if (res.state == FutureState.Successful) {
                s._right = s._thenFn(res.result.?);

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
    }
};
