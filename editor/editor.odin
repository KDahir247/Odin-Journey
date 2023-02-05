package editor


import "../mathematics"

Context :: struct{
    cursor_position : mathematics.Vec4i,
    grid_dimension : mathematics.Vec3i,
    line_clear_color : [4]u8,
    cursor_clear_color : [4]u8,
}