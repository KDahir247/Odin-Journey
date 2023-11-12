package journey

//THIS will have camera initalization a FX such as shaking and other FX
import "core:math/linalg/hlsl"


dx11_ortho_lhs :: proc(w,h : f32, near, far : f32) -> matrix[4,4]f32{
    return matrix[4,4]f32{
        2.0 / w, 0.0, 0.0, 0.0,
        0.0, 2.0 / h, 0.0, 0.0,
        0.0, 0.0, 1 / (far - near), 0.0,
        0.0, 0.0, near/(near - far), 1.0,
    }
}


dx11_lookat_lhs :: proc(eye_position : hlsl.float3, target_position : hlsl.float3, up : hlsl.float3) -> matrix[4,4]f32 {
    z_axis := hlsl.normalize_float3(target_position - eye_position)
    x_axis := hlsl.normalize_float3(hlsl.cross_float3(up, z_axis))
    y_axis := hlsl.cross(z_axis, x_axis)

    return matrix[4,4]f32{
        x_axis.x, x_axis.y, x_axis.z, -hlsl.dot_float3(x_axis, eye_position),
        y_axis.x, y_axis.y, y_axis.z, -hlsl.dot_float3(y_axis, eye_position),
        z_axis.x, z_axis.y, z_axis.z, -hlsl.dot_float3(z_axis, eye_position),
        0, 0, 0, 1,
    }
}