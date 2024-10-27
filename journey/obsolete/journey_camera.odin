package journey

//THIS will have camera initalization a FX such as shaking and other FX
import "core:math/linalg/hlsl"


//TODO:khal journey.camera will deal with camera matrix construction and adding camera fx like zooming, tweening, and group follow.



dx11_ortho_off_center_lhs :: proc(left, right, bottom, top :f32, near, far : f32) -> matrix[4,4]f32{
    
    rcp_width := 1/ (right - left)
    rcp_height := 1/ (top - bottom)
    range := 1.0 / (near - far)

    
    return  matrix[4,4]f32{
            rcp_width + rcp_width, 0.0, 0.0, 0.0,
            0.0, rcp_height + rcp_height, 0.0, 0.0,
            0.0, 0.0, range, 0.0,
            -(left + right) * rcp_width, -(top + bottom) * rcp_height, range * near, 1.0,
        }
}

dx11_ortho_lhs :: proc(w,h : f32, near, far : f32) -> (m : matrix[4,4]f32) #no_bounds_check{

    range := 1.0 / (far - near)

    m[0][0] = 2.0 / w
    m[1][0] = 0
    m[2][0] = 0
    m[3][0] = 0

    m[0][1] = 0
    m[1][1] = 2 / h
    m[2][1] = 0
    m[3][1] = 0

    m[0][2] = 0
    m[1][2] = 0
    m[2][2] = range
    m[3][2] = 0

    m[0][3] = 0
    m[1][3] = 0
    m[2][3] = -range * near
    m[3][3] = 1.0


    return
    // m[0][0] = 2.0 / w
    // m[0][1] = 0
    // m[0][2] = 0
    // m[0][3] = 0

    // m[1][0] = 0
    // m[1][1] = 2.0 / h
    // m[1][2] = 0
    // m[1][3] = 0

    // m[2][0] = 0
    // m[2][1] = 0
    // m[2][2] = range
    // m[2][3] = 0

    // m[3][0] = 0
    // m[3][1] = 0
    // m[3][2] = -range * near
    // m[3][3] = 1

}

dx11_ortho_rhs :: proc(w,h : f32, near, far : f32) -> matrix[4,4]f32{
    range := 1 / (near - far)

    return matrix[4,4]f32{
            2.0 / w, 0.0, 0.0, 0.0,
            0.0, 2.0 / h, 0.0, 0.0,
            0.0, 0.0, range, 0.0,
            0.0, 0.0, near * range, 1.0,
        }
}


dx11_lookat_rhs :: proc(eye_position : hlsl.float3, target_position : hlsl.float3, up : hlsl.float3) -> matrix[4,4]f32{
    eye_direction := eye_position - target_position;
    
    return dx11_lookat(eye_position, eye_direction, up)
}

dx11_lookat_lhs :: proc(eye_position : hlsl.float3, target_position : hlsl.float3, up : hlsl.float3) -> matrix[4,4]f32{
    eye_direction := target_position - eye_position

    return dx11_lookat(eye_position, eye_direction, up)
}


dx11_lookat :: proc(eye_position : hlsl.float3, eye_direction : hlsl.float3, up : hlsl.float3) ->  matrix[4,4]f32 {
    
    z_axis := hlsl.normalize_float3(eye_direction)
    x_axis := hlsl.normalize_float3(hlsl.cross_float3(up, z_axis))
    y_axis := hlsl.cross( z_axis, x_axis)


    return matrix[4,4]f32{
        x_axis.x, y_axis.x, z_axis.x, 0,
        x_axis.y, y_axis.y, z_axis.y, 0,
        x_axis.z, y_axis.z, z_axis.z, 0,
        -hlsl.dot_float3(x_axis, eye_position), -hlsl.dot_float3(y_axis, eye_position), -hlsl.dot_float3(z_axis, eye_position), 1,
    }

    // return matrix[4,4]f32{
    //     x_axis.x, x_axis.y, x_axis.z, -hlsl.dot_float3(x_axis, eye_position),
    //     y_axis.x, y_axis.y, y_axis.z, -hlsl.dot_float3(y_axis, eye_position),
    //     z_axis.x, z_axis.y, z_axis.z, -hlsl.dot_float3(z_axis, eye_position),
    //     0, 0, 0, 1,
    // }
}