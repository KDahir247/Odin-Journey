package journey



//////////////////// COMMAN MATH ///////////////////////
  
IDENTITY : matrix[4,4]f32 :  {
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0,
}


//////////////////// COMMON PATH ///////////////////////
CONFIG_BYTES :: #load("../resource/game_config.json")

CACHED_SHARED_PATH :[1]string = {
    "resource/shader/sprite_instancing.hlsl",
} 

DEFAULT_SPRITE_PATH :: "resource/sprite/*.png"

DEFAULT_SHADER_PATH :: "resource/shader/*.hlsl"

//Quality 1, Size = 4
DEFAULT_AUDIO_PATH_WAV :: "reosurce/audio/*.wav"

//Quality 2, Size = 3
DEFAULT_AUDIO_PATH_FLAC :: "resource/audio/*.flac"

//Quality 3, Size = 2
DEFAULT_AUDIO_PATH_OGG :: "resource/audio/*.ogg"

//Quality 4, Size = 1
DEFAULT_AUDIO_PATH_MP3 :: "resource/aduio/*.mp3"

//////////////////// COMMON VARIABLES //////////////////

TIME_SCALE : f32 :  1.0
MAX_DELTA_TIME : f32: (1.0 / 60.0) * TIME_SCALE

GRAVITY :: 9.81
///////////////////////////////////////////////////////

/////////////////// RENDERER DATA /////////////////////
INSTANCE_BYTE_WIDTH :: size_of(RenderInstanceData) << 14

ResourceCache :: struct{
    render_buffer : ^RenderBatchBuffer,
}

SpriteIndex :: struct{
    position : [2]f32,
}

GlobalDynamicVSConstantBuffer :: struct #align (16){
    projection_matrix : matrix[4,4]f32,
    view_matrix : matrix[4,4]f32,

    viewport_x : f32,
    viewport_y : f32,
    viewport_width : f32,
    viewport_height : f32,
}

GlobalDynamicPSConstantBuffer :: struct #align (16){
    time : f32,
    delta_time : f32,
}

RenderBatchBuffer :: struct #align (64){
    render_batch_groups : map[uint]RenderBatchGroup,
    camera : Camera,
    changed_flag : bool,

}

RenderBatchGroup :: struct{
    texture_param : TextureParam,
    instances : [dynamic]RenderInstanceData, 
}

RenderInstanceData :: struct #align (16){
    transform : matrix[4,4]f32,
    src_rect : [4]f32,
    color : [4]f32,
    //1 is true, 0 is false
    flip_bit : [2]f32,
    center : [2]f32,
    order_index : int,
}

/////////////

TextureParam :: struct{
    texture : rawptr,
    width : i32,
    height : i32,
    shader_cache : u32,
}
////////////////////////////////////////////////////////


/////////////////// GAME DATA /////////////////////////

//1 = Left, 0 = Right
Direction :: enum i32{
    Left_Top = 0b11, //1,1 
    Right_Top = 0b01, //0,1
    Left_Bottom = 0b10, //1,0
    Right_Bottom = 0b00, //0,0
}

TextureType :: enum i32{
    SpriteSheet = 0,
    Individual = 1,
}

EntityDescriptor :: struct{
    position : [2]f32,
    scale : [2]f32,
    color : [4]f32,
    rotation : f32,
    sprite_texture_type : TextureType,
    direction : Direction,
}

RenderInstance :: struct{
    hash : uint,
    instance_index : uint,
}

Position :: struct{
    x : f32,
    y : f32,
}

Rotation :: struct{
    z : f32,
}

Scale :: struct {
    x : f32,
    y : f32,
}

Rect :: struct{
    x : f32,
    y : f32,
    width : f32,
    height : f32,
}

PhysicsRect :: struct{
    x : f32,
    y : f32,
    half_width : f32,
    half_height : f32,
}


Color :: struct{
    r : f32,
    g : f32,
    b : f32,
    a : f32,
}

//1 is true, 0 is false
Flip :: struct{
    x : i32,
    y : i32,
}

//TODO:khal remove
// Animator :: struct{
//     clips :[]Animation,
//     animation_speed : f32,
//     current_clip : int,
//     animation_duration_sec : f32,
// }

Animation :: struct{
    width : int, // (the sprite width for the animation clip)
    height : int, // (the sprite height for the animation clip)
    index : int, // (the row the animation strip is in)
    len : int, // (how much column the animation has aka. the number of clips)
    // carry_over : int, // (if the animation continues over from the index to the next index what index is it carried over to and how much column does it take up. 0 mean no carry over 1 mean the it will take 1 column from the next row, etc...)
    // offset_slice : int, // (how much column should be be skipped in the sprite sheet)
    // animation_speed : int, // (the speed of the animation 1.0x mean normal, 2.0x mean 2 times etc...)
    // loop : int, // (looping animation clip. 1 is looping, 0 mean doesn't loop)
}

CollisionHit :: struct{
    collider : Collider,
    contact_point : [2]f32, // the collision point.
    delta_displacement : [2]f32,//  vector to add move collided AABB back to non collided state.
    contact_normal : [2]f32,
    time : f32, //how far along the line the collision occurred (0,1)
}   

CollisionSweep :: struct{
    hit : CollisionHit,
    pos : [2]f32,
    time : f32,
}
//

CollisionResolver :: struct{
    collision_iteration : int,
    used_iteration : int,
}

PhysicsContacts :: struct{
    contacts : []PhysicsContact,
}

PhysicsContact :: struct{
    collider : uint,
    collided : uint,
    collision_normal_x : f32,
    collision_normal_y : f32,
    collision_point_x : f32,
    collision_point_y : f32,
    restitution  : f32,
    penetration : f32,
}

Collider :: struct{
    center_x : f32,
    center_y : f32,
    half_extent_x : f32,
    half_extent_y : f32,
}

Velocity :: struct{
    x : f32,
    y : f32,
    previous_x : f32,
    previous_y : f32,
}

Acceleration :: struct{
    x : f32,
    y : f32,
}

InverseMass :: struct{
    val : f32, 
}

AccumulatedForce :: struct{
    x : f32,
    y : f32,
}

DynamicFriction :: struct{
    val : f32,
}

StaticFriction :: struct{
    val : f32,
}

Restitution :: struct{
    val : f32,
}

RBlend :: enum u32{
    Maximum = 0,
    Minimum = 1,
    Average = 2,
    Multiply = 3,
}

RestitutionBlend :: struct{
    val : RBlend,
}

Force :: struct{
    x : f32,
    y : f32,
}

///////////////////////////////////////////////////////

/////////////////// RESOURCE DATA /////////////////////////

Camera :: struct{
    look_at_x : f32,
    look_at_y : f32,
}

GameController :: struct{
    key_buffer : []i8,
}

///////////////////////////////////////////////////////


