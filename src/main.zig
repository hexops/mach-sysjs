const std = @import("std");
const testing = std.testing;
const Ast = std.zig.Ast;
const IrGen = @import("IrGen.zig");

pub fn generateFiles(
    allocator: std.mem.Allocator,
    bindings_path: []const u8,
    generated_sysjs_zig: []const u8,
    generated_sysjs_js: []const u8,
) !void {
    var generated_zig = try std.fs.cwd().createFile(generated_sysjs_zig, .{});
    var generated_js = try std.fs.cwd().createFile(generated_sysjs_js, .{});
    const bindings_code = try std.fs.cwd().readFileAllocOptions(allocator, bindings_path, 1024 * 1024 * 128, null, @alignOf(u8), 0);
    defer allocator.free(bindings_code);

    const zig_writer = generated_zig.writer();
    const js_writer = generated_js.writer();
    var gen = Generator(@TypeOf(zig_writer), @TypeOf(js_writer)){
        .zig = zig_writer,
        .js = js_writer,
        .allocator = allocator,
        .bindings_code = bindings_code,
    };
    try gen.root();

    generated_zig.close();
    generated_js.close();
}

fn Generator(comptime ZigWriter: type, comptime JSWriter: type) type {
    return struct {
        zig: ZigWriter,
        js: JSWriter,
        allocator: std.mem.Allocator,
        bindings_code: [:0]const u8,

        // internal fields
        tree: Ast = undefined,
        buf: [4096]u8 = undefined,
        namespace: std.ArrayListUnmanaged([]const u8) = .{},

        pub fn root(gen: *@This()) !void {
            gen.tree = try Ast.parse(gen.allocator, gen.bindings_code, .zig);
            defer gen.tree.deinit(gen.allocator);

            try std.fmt.format(gen.zig, "// Generated by `zig build`; DO NOT EDIT.\n", .{});
            try std.fmt.format(gen.js, "// Generated by `zig build`; DO NOT EDIT.\n", .{});

            var irgen = IrGen{
                .allocator = gen.allocator,
                .ast = gen.tree,
            };

            try irgen.addRoot();

            try gen.generateJsScaffold();
            try irgen.root.emitZig(gen.allocator, gen.zig, 0);
            try irgen.root.emitJs(gen.allocator, gen.js, 0);
        }

        fn generateJsScaffold(gen: *@This()) !void {
            try gen.js.writeAll(
                \\let wasm = undefined;
                \\let wasm_memory_buf = undefined;
                \\function wasmGetMemory() {
                \\    if (wasm_memory_buf === undefined || wasm_memory_buf !== wasm.memory.buffer) {
                \\        wasm_memory_buf = new Uint8Array(wasm.memory.buffer);
                \\    }
                \\    return wasm_memory_buf;
                \\}
                \\
                \\function wasmGetDataView() {
                \\    return new DataView(wasm.memory.buffer);
                \\}
                \\
                \\function wasmGetSlice(ptr, len) {
                \\    return wasmGetMemory().slice(ptr, ptr + len);
                \\}
                \\
                \\let wasm_objects = [];
                \\function wasmWrapObject(obj) {
                \\    return wasm_objects.push(obj) - 1;
                \\}
                \\
                \\function wasmGetObject(id) {
                \\    return wasm_objects[id];
                \\}
                \\
                \\export function init(wasmObj) {
                \\    wasm = wasmObj;
                \\}
                \\
                \\/* Gen */
                \\
            );
        }
    };
}
