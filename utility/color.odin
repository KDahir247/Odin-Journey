package utility

hex_to_rgb :: #force_inline proc(hex : int, $normalize : bool) -> [3]f32{ 

    r := f32((hex >> 16) & 0xFF)
    g := f32((hex >> 8) & 0xFF)
    b := f32((hex) & 0xFF)

    when normalize{
        r /= 255
        g /= 255
        b /= 255
    }

    return {r, g, b}
}