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

    pub fn catchError(self: Future, alloc: std.mem.Allocator, catchFn: *const fn (alloc: std.mem.Allocator, err: anyerror) Future) Future {
        const f = alloc.create(Catch) catch {
            @panic("out of memory");
        };

        f.* = Catch{
            ._left = self,
            ._thenFn = catchFn,
            ._alloc = alloc,
        };

        return f.future();
    }
};

pub const Catch = struct {
    _left: ?Future,
    _right: ?Future = null,
    _thenFn: *const fn (alloc: std.mem.Allocator, res: anyerror) Future,
    _alloc: std.mem.Allocator,

    pub fn future(self: *Catch) Future {
        return .{
            .ptr = self,
            .vtable = &.{
                .poll = poll,
                .deinit = deinit,
            },
        };
    }

    pub fn poll(self: *anyopaque) anyerror!Result {
        var s: *Catch = @ptrCast(@alignCast(self));

        if (s._left) |l| {
            const res = l.poll() catch |err| {
                s._right = s._thenFn(s._alloc, err);

                s._left = null;

                l.deinit();

                return .{ .state = FutureState.Pending, .result = null };
            };

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
            std.debug.print("{any}\n", .{res.state});

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

pub const Done = struct {
    _res: *anyopaque = undefined,
    _alloc: std.mem.Allocator,

    pub fn future(self: *Done) Future {
        return .{
            .ptr = self,
            .vtable = &.{
                .poll = poll,
                .deinit = deinit,
            },
        };
    }

    pub fn poll(ctx: *anyopaque) anyerror!Result {
        const self: *Done = @ptrCast(@alignCast(ctx));

        return Result{ .state = FutureState.Successful, .result = self._res };
    }

    pub fn deinit(val: *anyopaque) void {
        var self: *Done = @ptrCast(@alignCast(val));

        self._alloc.destroy(self);
    }
};
