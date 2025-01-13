const std = @import("std");

// const ThenFn = fn (comptime T: type) T;

pub const FutureState = enum {
    Pending,
    Successful,
    Rejected,
};

pub const Result = struct {
    state: FutureState,
    result: ?*anyopaque,
};

const VTable = struct {
    poll: *const fn (*anyopaque) Result,
    deinit: *const fn (*anyopaque) void,
};

pub const Future = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub fn poll(self: *Future) Result {
        return self.vtable.poll(self.ptr);
    }

    pub fn deinit(self: *Future) void {
        self.deinit(self.ptr);
    }
};
