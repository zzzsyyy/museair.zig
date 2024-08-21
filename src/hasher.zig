const std = @import("std");
const mem = std.mem;
const math = std.math;

const State = [6]u64;

const DEFAULT_SECRET: [6]u64 = .{
    0x5ae31e589c56e17a,
    0x96d7bb04e64f6da9,
    0x7ab1006b26f9eb64,
    0x21233394220b8457,
    0x047cb9557c9f3b43,
    0xd24f2590c0bcee28,
};

const INIT_RING_PREV: u64 = 0x33ea8f71bb6016d8;

inline fn seg(comptime n: u32) u32 {
    return n * 8;
}

inline fn u128_to_u64s(x: u128) [2]u64 {
    return .{ @truncate(x), @truncate(x >> 64) };
}

inline fn u64s_to_u128(lo: u64, hi: u64) u128 {
    return (@as(u128, hi) << 64) | @as(u128, lo);
}

inline fn wmul(a: u64, b: u64) [2]u64 {
    return u128_to_u64s(@as(u128, a) * @as(u128, b));
}

inline fn read_u32(bytes: []const u8) u64 {
    const value = mem.readVarInt(u32, bytes[0..4], .little);
    return @intCast(value);
}

inline fn read_u64(bytes: []const u8) u64 {
    return mem.readVarInt(u64, bytes[0..8], .little);
}

inline fn read_short(bytes: []const u8) [2]u64 {
    const len = bytes.len;
    if (len >= 4) {
        const off: usize = (len & 24) >> @intCast(len >> 3);
        return .{ (read_u32(bytes[0..]) << 32) | read_u32(bytes[len - 4 ..]), (read_u32(bytes[off..]) << 32) | read_u32(bytes[len - 4 - off ..]) };
    } else if (len > 0) {
        return .{
            ((@as(u64, bytes[0]) << 48) | (@as(u64, bytes[len >> 1]) << 24) | @as(u64, bytes[len - 1])),
            0,
        };
    } else {
        return .{ 0, 0 };
    }
}

inline fn _frac_6(comptime BFAST: bool, st: [2]u64, vw: [2]u64) [2]u64 {
    var s, var t = st;
    const v, const w = vw;
    s ^= v;
    t ^= w;

    if (!BFAST) {
        const value = wmul(s, t);
        return .{ s ^ value[0], t ^ value[1] };
    } else {
        return wmul(s, t);
    }
}

inline fn _frac_3(comptime BFAST: bool, s: u64, t: u64, v: u64) [2]u64 {
    const tt = t ^ v;
    if (!BFAST) {
        const value = wmul(s, tt);
        return .{ s ^ value[0], tt ^ value[1] };
    } else {
        return wmul(s, tt);
    }
}

inline fn _chixx(t: u64, u: u64, v: u64) [3]u64 {
    return .{ t ^ (~u & v), u ^ (~v & t), v ^ (~t & u) };
}

inline fn _tower_layer_12(comptime BFAST: bool, state: *State, bytes: []const u8, ring_prev: u64) struct { State, u64 } {
    if (!BFAST) {
        state[0] ^= read_u64(bytes[seg(0)..]);
        state[1] ^= read_u64(bytes[seg(1)..]);
        const lo0, const hi0 = wmul(state[0], state[1]);
        state[0] = state[0] +% (ring_prev ^ hi0);

        state[1] ^= read_u64(bytes[seg(2)..]);
        state[2] ^= read_u64(bytes[seg(3)..]);
        const lo1, const hi1 = wmul(state[1], state[2]);
        state[1] = state[1] +% (lo0 ^ hi1);

        state[2] ^= read_u64(bytes[seg(4)..]);
        state[3] ^= read_u64(bytes[seg(5)..]);
        const lo2, const hi2 = wmul(state[2], state[3]);
        state[2] = state[2] +% (lo1 ^ hi2);

        state[3] ^= read_u64(bytes[seg(6)..]);
        state[4] ^= read_u64(bytes[seg(7)..]);
        const lo3, const hi3 = wmul(state[3], state[4]);
        state[3] = state[3] +% (lo2 ^ hi3);

        state[4] ^= read_u64(bytes[seg(8)..]);
        state[5] ^= read_u64(bytes[seg(9)..]);
        const lo4, const hi4 = wmul(state[4], state[5]);
        state[4] = state[4] +% (lo3 ^ hi4);

        state[5] ^= read_u64(bytes[seg(10)..]);
        state[0] ^= read_u64(bytes[seg(11)..]);
        const lo5, const hi5 = wmul(state[5], state[0]);
        state[5] = state[5] +% (lo4 ^ hi5);

        return .{ state.*, lo5 };
    } else {
        state[0] ^= read_u64(bytes[seg(0)..]);
        state[1] ^= read_u64(bytes[seg(1)..]);
        const lo0, const hi0 = wmul(state[0], state[1]);
        state[0] = ring_prev ^ hi0;

        state[1] ^= read_u64(bytes[seg(2)..]);
        state[2] ^= read_u64(bytes[seg(3)..]);
        const lo1, const hi1 = wmul(state[1], state[2]);
        state[1] = lo0 ^ hi1;

        state[2] ^= read_u64(bytes[seg(4)..]);
        state[3] ^= read_u64(bytes[seg(5)..]);
        const lo2, const hi2 = wmul(state[2], state[3]);
        state[2] = lo1 ^ hi2;

        state[3] ^= read_u64(bytes[seg(6)..]);
        state[4] ^= read_u64(bytes[seg(7)..]);
        const lo3, const hi3 = wmul(state[3], state[4]);
        state[3] = lo2 ^ hi3;

        state[4] ^= read_u64(bytes[seg(8)..]);
        state[5] ^= read_u64(bytes[seg(9)..]);
        const lo4, const hi4 = wmul(state[4], state[5]);
        state[4] = lo3 ^ hi4;

        state[5] ^= read_u64(bytes[seg(10)..]);
        state[0] ^= read_u64(bytes[seg(11)..]);
        const lo5, const hi5 = wmul(state[5], state[0]);
        state[5] = lo4 ^ hi5;

        return .{ state.*, lo5 };
    }
}

inline fn _tower_layer_6(comptime BFAST: bool, state: *State, bytes: []const u8) State {
    state[0], state[1] = _frac_6(BFAST, .{ state[0], state[1] }, .{ read_u64(bytes[seg(0)..]), read_u64(bytes[seg(1)..]) });
    state[2], state[3] = _frac_6(BFAST, .{ state[2], state[3] }, .{ read_u64(bytes[seg(2)..]), read_u64(bytes[seg(3)..]) });
    state[4], state[5] = _frac_6(BFAST, .{ state[4], state[5] }, .{ read_u64(bytes[seg(4)..]), read_u64(bytes[seg(5)..]) });
    return state.*;
}

inline fn _tower_layer_3(comptime BFAST: bool, state: *State, bytes: []const u8) State {
    state[0], state[3] = _frac_3(BFAST, state[0], state[3], read_u64(bytes[seg(0)..]));
    state[1], state[4] = _frac_3(BFAST, state[1], state[4], read_u64(bytes[seg(1)..]));
    state[2], state[5] = _frac_3(BFAST, state[2], state[5], read_u64(bytes[seg(2)..]));
    return state.*;
}

inline fn _tower_layer_0(state: *State, bytes: []const u8, tot_len: u64) [3]u64 {
    var i, var j, var k = [3]u64{ 0, 0, 0 };

    const len = bytes.len;
    //debug_assert!(len <= seg!(3));
    if (len <= seg(2)) {
        i, j = read_short(bytes);
        k = 0;
    } else {
        i = read_u64(bytes[seg(0)..]);
        j = read_u64(bytes[seg(1)..]);
        k = read_u64(bytes[len - seg(1) ..]);
    }

    if (tot_len >= seg(3)) {
        state[0], state[2], state[4] = _chixx(state[0], state[2], state[4]);
        state[1], state[3], state[5] = _chixx(state[1], state[3], state[5]);
        i ^= state[0] +% (state[1]);
        j ^= state[2] +% (state[3]);
        k ^= state[4] +% (state[5]);
    } else {
        i ^= state[0];
        j ^= state[1];
        k ^= state[2];
    }

    return .{ i, j, k };
}

inline fn _tower_layer_x(comptime BFAST: bool, ijk: [3]u64, tot_len: u64) [3]u64 {
    const rot = @as(u32, @truncate(tot_len)) & 0b11_1111;
    var i, var j, var k = ijk;
    i, j, k = _chixx(i, j, k);
    i = math.rotl(u64, i, rot);
    j = math.rotr(u64, j, rot);
    k ^= tot_len;
    if (!BFAST) {
        const lo0, const hi0 = wmul(i ^ DEFAULT_SECRET[3], j);
        const lo1, const hi1 = wmul(j ^ DEFAULT_SECRET[4], k);
        const lo2, const hi2 = wmul(k ^ DEFAULT_SECRET[5], i);
        return .{ i ^ lo0 ^ hi2, j ^ lo1 ^ hi0, k ^ lo2 ^ hi1 };
    } else {
        const lo0, const hi0 = wmul(i, j);
        const lo1, const hi1 = wmul(j, k);
        const lo2, const hi2 = wmul(k, i);
        return .{ lo0 ^ hi2, lo1 ^ hi0, lo2 ^ hi1 };
    }
}

inline fn tower_loong(comptime BFAST: bool, bytes: []const u8, seed: u64) [3]u64 {
    const tot_len: u64 = bytes.len;
    var off: usize = 0;
    var rem = tot_len;
    var state: State = DEFAULT_SECRET;

    state[0] = state[0] +% (seed);
    state[1] = state[1] -% (seed);
    state[2] ^= seed;

    if (rem >= seg(12)) {
        state[3] = state[3] +% (seed);
        state[4] = state[4] -% (seed);
        state[5] ^= seed;

        var ring_prev = INIT_RING_PREV;
        while (true) {
            state, ring_prev = _tower_layer_12(BFAST, &state, bytes[off..], ring_prev);
            off += seg(12);
            rem -= seg(12);
            if (rem < seg(12)) {
                @setCold(true);
                break;
            }
        }

        state[0] ^= ring_prev;
    }

    if (rem >= seg(6)) {
        state = _tower_layer_6(BFAST, &state, bytes[off..]);
        off += seg(6);
        rem -= seg(6);
    }

    if (rem >= seg(3)) {
        state = _tower_layer_3(BFAST, &state, bytes[off..]);
        off += seg(3);
    }

    return _tower_layer_x(BFAST, _tower_layer_0(&state, bytes[off..], tot_len), tot_len);
}

inline fn tower_short(bytes: []const u8, seed: u64) [2]u64 {
    const len: u64 = bytes.len;
    const i, const j = read_short(bytes);
    const lo, const hi = wmul(seed ^ DEFAULT_SECRET[0], len ^ DEFAULT_SECRET[1]);
    return .{ i ^ lo ^ len, j ^ hi ^ seed };
}

inline fn epi_short(ij: [2]u64) u64 {
    var i, var j = ij;
    i ^= DEFAULT_SECRET[2];
    j ^= DEFAULT_SECRET[3];
    const lo1, const hi1 = wmul(i, j);
    i ^= lo1 ^ DEFAULT_SECRET[4];
    j ^= hi1 ^ DEFAULT_SECRET[5];
    const lo2, const hi2 = wmul(i, j);
    return i ^ j ^ lo2 ^ hi2;
}

inline fn epi_short_128(comptime BFAST: bool, ij: [2]u64) u128 {
    var i, var j = ij;
    if (!BFAST) {
        const lo0, const hi0 = wmul(i ^ DEFAULT_SECRET[2], j);
        const lo1, const hi1 = wmul(i, j ^ DEFAULT_SECRET[3]);
        i ^= lo0 ^ hi1;
        j ^= lo1 ^ hi0;
        const lo3, const hi3 = wmul(i ^ DEFAULT_SECRET[4], j);
        const lo4, const hi4 = wmul(i, j ^ DEFAULT_SECRET[5]);
        return u64s_to_u128(i ^ lo3 ^ hi4, j ^ lo4 ^ hi3);
    } else {
        const lo0, const hi0 = wmul(i, j);
        const lo1, const hi1 = wmul(i ^ DEFAULT_SECRET[2], j ^ DEFAULT_SECRET[3]);
        i = lo0 ^ hi1;
        j = lo1 ^ hi0;
        const lo3, const hi3 = wmul(i, j);
        const lo4, const hi4 = wmul(i ^ DEFAULT_SECRET[4], j ^ DEFAULT_SECRET[5]);
        return u64s_to_u128(lo3 ^ hi4, lo4 ^ hi3);
    }
}

inline fn epi_loong(comptime BFAST: bool, ijk: [3]u64) u64 {
    var i, var j, var k = ijk;
    if (!BFAST) {
        const lo0, const hi0 = wmul(i ^ DEFAULT_SECRET[0], j);
        const lo1, const hi1 = wmul(j ^ DEFAULT_SECRET[1], k);
        const lo2, const hi2 = wmul(k ^ DEFAULT_SECRET[2], i);
        i ^= lo0 ^ hi2;
        j ^= lo1 ^ hi0;
        k ^= lo2 ^ hi1;
    } else {
        const lo0, const hi0 = wmul(i, j);
        const lo1, const hi1 = wmul(j, k);
        const lo2, const hi2 = wmul(k, i);
        i = lo0 ^ hi2;
        j = lo1 ^ hi0;
        k = lo2 ^ hi1;
    }
    return i +% j +% k;
}

inline fn epi_loong_128(comptime BFAST: bool, ijk: [3]u64) u128 {
    var i, var j, const k = ijk;
    if (!BFAST) {
        const lo0, const hi0 = wmul(i ^ DEFAULT_SECRET[0], j);
        const lo1, const hi1 = wmul(j ^ DEFAULT_SECRET[1], k);
        const lo2, const hi2 = wmul(k ^ DEFAULT_SECRET[2], i);
        i ^= lo0 ^ lo1 ^ hi2;
        j ^= hi0 ^ hi1 ^ lo2;
    } else {
        const lo0, const hi0 = wmul(i, j);
        const lo1, const hi1 = wmul(j, k);
        const lo2, const hi2 = wmul(k, i);
        i = lo0 ^ lo1 ^ hi2;
        j = hi0 ^ hi1 ^ lo2;
    }
    return u64s_to_u128(i, j);
}

inline fn base_hash(comptime BFAST: bool, bytes: []const u8, seed: u64) u64 {
    if (bytes.len <= seg(2)) {
        return epi_short(tower_short(bytes, seed));
    } else {
        @setCold(true);
        return epi_loong(BFAST, tower_loong(BFAST, bytes, seed));
    }
}

inline fn base_hash_128(comptime BFAST: bool, bytes: []const u8, seed: u64) u128 {
    if (bytes.len <= seg(2)) {
        return epi_short_128(BFAST, tower_short(bytes, seed));
    } else {
        @setCold(true);
        return epi_loong_128(BFAST, tower_loong(BFAST, bytes, seed));
    }
}

pub inline fn hash(bytes: []const u8, seed: u64) u64 {
    return base_hash(false, bytes, seed);
}

pub inline fn hash_128(bytes: []const u8, seed: u64) u128 {
    return base_hash_128(false, bytes, seed);
}
