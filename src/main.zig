const std = @import("std");

pub fn main() !void {
    const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080);

    var server = try addr.listen(.{ .reuse_address = true });
    defer server.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer {
        std.debug.assert(gpa.deinit() == std.heap.Check.ok);
    }

    const alloc = gpa.allocator();

    var pool = try ConnPool.init(alloc, 1);
    defer pool.deinit();

    while (true) {
        const conn = try server.accept();

        const connPtr = try pool.acquire();

        connPtr.* = conn;

        // try handleConn(conn);
        const thread = try std.Thread.spawn(.{ .stack_size = 10 * 1024 }, handleConn, .{ connPtr, pool });

        thread.detach();
    }
}

fn handleConn(
    conn: *std.net.Server.Connection,
    pool: *ConnPool,
) !void {
    defer pool.relese(conn);

    std.debug.print("New client\n", .{});
    defer std.debug.print("Client closed\n", .{});

    while (true) {
        const stream = conn.stream;
        // defer stream.close();

        var buf: [1024]u8 = undefined;
        const n = try stream.read(&buf);
        if (n == 0) {
            stream.close();

            return;
        }

        _ = try stream.write(buf[0..n]);
    }
}

const ConnPool = struct {
    _alloc: std.mem.Allocator,
    _mut: std.Thread.Mutex,
    _buff: []*std.net.Server.Connection,
    _pos: usize,

    pub fn init(alloc: std.mem.Allocator, size: usize) !*ConnPool {
        const p = try alloc.create(ConnPool);
        const arr = try alloc.alloc(*std.net.Server.Connection, size);

        for (arr, 0..) |_, i| {
            const conn = try alloc.create(std.net.Server.Connection);

            arr[i] = conn;
        }

        p.* = .{
            ._mut = .{},
            ._alloc = alloc,
            ._buff = arr,
            ._pos = size,
        };

        return p;
    }

    pub fn deinit(self: *ConnPool) void {
        const alloc = self._alloc;

        for (self._buff) |conn| {
            alloc.destroy(conn);
        }

        alloc.free(self._buff);
        alloc.destroy(self);
    }

    pub fn acquire(self: *ConnPool) !*std.net.Server.Connection {
        self._mut.lock();

        if (self._pos == 0) {
            // dont hold the lock over factory
            self._mut.unlock();

            const alloc = try self._alloc.create(std.net.Server.Connection);

            return alloc;
        }

        self._pos -= 1;

        const conn = self._buff[self._pos];

        self._mut.unlock();

        std.debug.print("new pos: {d}\n", .{self._pos});

        return conn;
    }

    pub fn relese(self: *ConnPool, conn: *std.net.Server.Connection) void {
        self._mut.lock();

        conn.*.address = undefined;
        conn.*.stream = undefined;

        if (self._pos == self._buff.len) {
            self._mut.unlock();
            self._alloc.destroy(conn);

            return;
        }

        self._buff[self._pos] = conn;
        self._pos += 1;

        std.debug.print("pos: {d}\n", .{self._pos});
        self._mut.unlock();
    }
};
