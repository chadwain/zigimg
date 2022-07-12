const builtin = std.builtin;
const std = @import("std");
const io = std.io;
const meta = std.meta;
const errors = @import("errors.zig");

const native_endian = @import("builtin").target.cpu.arch.endian();

pub fn toMagicNumberNative(magic: []const u8) u32 {
    var result: u32 = 0;
    for (magic) |character, index| {
        result |= (@as(u32, character) << @intCast(u5, (index * 8)));
    }
    return result;
}

pub fn toMagicNumberForeign(magic: []const u8) u32 {
    var result: u32 = 0;
    for (magic) |character, index| {
        result |= (@as(u32, character) << @intCast(u5, (magic.len - 1 - index) * 8));
    }
    return result;
}

pub const toMagicNumberBig = switch (native_endian) {
    builtin.Endian.Little => toMagicNumberForeign,
    builtin.Endian.Big => toMagicNumberNative,
};

pub const toMagicNumberLittle = switch (native_endian) {
    builtin.Endian.Little => toMagicNumberNative,
    builtin.Endian.Big => toMagicNumberForeign,
};

pub fn readStructNative(reader: io.StreamSource.Reader, comptime T: type) errors.ImageReadError!T {
    return try reader.readStruct(T);
}

pub fn readStructForeign(reader: io.StreamSource.Reader, comptime T: type) errors.ImageReadError!T {
    comptime std.debug.assert(@typeInfo(T).Struct.layout != builtin.TypeInfo.ContainerLayout.Auto);

    var result: T = undefined;

    inline for (meta.fields(T)) |entry| {
        switch (@typeInfo(entry.field_type)) {
            .ComptimeInt, .Int => {
                @field(result, entry.name) = try reader.readIntForeign(entry.field_type);
            },
            .Struct => {
                @field(result, entry.name) = try readStructForeign(reader, entry.field_type);
            },
            .Enum => {
                @field(result, entry.name) = reader.readEnum(entry.field_type, switch (native_endian) {
                    builtin.Endian.Little => builtin.Endian.Big,
                    builtin.Endian.Big => builtin.Endian.Little,
                }) catch return error.InvalidData;
            },
            else => {
                @compileError(std.fmt.comptimePrint("Add support for type {} in readStructForeign", .{@typeName(entry.field_type)}));
            },
        }
    }

    return result;
}

pub const readStructLittle = switch (native_endian) {
    builtin.Endian.Little => readStructNative,
    builtin.Endian.Big => readStructForeign,
};

pub const readStructBig = switch (native_endian) {
    builtin.Endian.Little => readStructForeign,
    builtin.Endian.Big => readStructNative,
};
