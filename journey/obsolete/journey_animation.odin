package journey

import "core:fmt"
import "core:os"
import "core:encoding/json"
import "core:hash"
import "core:intrinsics"

// Thoughs. This will have Spine2D Support in the future.
// Currently I will implement a simple Sprite Sheet animation.
// This will get more complex later such as sprite reskinning. 
// This wouldn't work for sprite sheet, but will work for sliced sprite
// Such as https://github.com/EsotericSoftware/spine-runtimes/blob/4.1/spine-sdl/data/spineboy.png
// Both Sprite Sheet and Sprite slice will support hot reloading.
// Note that to allow hot reloading journey_animation will depend on journey_asset and the journey_asset
// Will only work for windows for the time being, so linux and mac shouldn't use hot reloading till all platform are supported.
// A nice to have feature would be having different Rect for each sprite in the animation clip
// We will have two Rect in the animation clip one for Uniform for the animation system and the other as non-uniform for
// More fine grain system such as the collision system.

//Eg.

//IDLE 

/*
    This will also dynamically change the AABB for the collision detection so if the player idle clip
    Contains a crouch any projectiles that will hit the top for the First frame idle clip will miss in the 
    Second frame idle clip.

First frame Idle
    |-------|
    |       |           Second frame idle (Crouch)
    |       |           |-------|
    |       |           |       |
    |       |           |       |
    |_______|           |_______|

*/


// Animation Clip (Sprite Sheet) Structure
// We want to how how much Column the animation takes up
// We want to know how much rows the animation clip takes up
// We want to know the width and height of the animation Rect
// We can assume all the sprites in this animation clip has the same width and height (Uniform).
// we want to also hold the non-uniform Rect of the clip bounds for percise systems we will call this bounds
// We want to know the animation clip speed.
// We want to know if the clip is loopable
// We want to know if the current clip has to complete a full cycle before transitioning
// We want to know if it is horizontal or vertically sliced


//Add offset len fir example we are playing a fire sprite sheet. the first 5 frame are the fire getting ingited
//



//Sprite Sheet Animator Structure
// We need to hold the clips 
// We want animation_duration_sec. How long each frame take 
// we want the current clip playing
// 

// LoadOperation :: enum{
//     Runtime, // Load the content at runtime.
//     Compiletime, // Load the content at compile time
// }


// create_animator :: proc($clips_path : string, $op : LoadOperation, allocator := context.temp_allocator, animation_speed : f32 = 1.0) -> (Animator, []AnimationClip){
    

//    //TODO: khal this will be handled by the file system later when implmented. 
//    animation_clips_bytes, _ := os.read_entire_file_from_filename(clips_path)
//     animation_json, err := json.parse(animation_clips_bytes,json.Specification.JSON5, true)
    
//     delete(animation_clips_bytes)

//     defer if err == json.Error.None{
//         json.destroy_value(animation_json)
//     }

//     animator : Animator
//     animator.animator_string_hash = hash.fnv32(transmute([]u8)clips_path)

//     root := animation_json.(json.Object)

//     starting_clip := root["starting_clip"].(json.String)
//     starting_clip_hash := hash.fnv32(transmute([]u8)starting_clip)

//     animator.clip_string_hash = starting_clip_hash

//     animator.rect_size = f32(root["size"].(json.Float))

//     animator.animation_speed = animation_speed

//     animator.animation_duration = f32(root["animation_duration"].(json.Float))

//     clips_object_array := root["clips"].(json.Array)

//     animation_clips := make_slice([]AnimationClip, len(clips_object_array), allocator)

//     for clip_object, index in clips_object_array{
//         clip := clip_object.(json.Object)

//         clip_name := clip["name"].(json.String)
//         half_bounds := clip["half_bounds"].(json.Array)

//         //TODO:khal implement half_bounds

//         clip_len : = f32(clip["len"].(json.Float))
//         clip_index := f32(clip["index"].(json.Float))

//         clip_direction := i32(clip["direction"].(json.Integer))
        
//         animation_clips[index].len = clip_len
//         animation_clips[index].index = clip_index
//         animation_clips[index].name_hash = hash.fnv32(transmute([]u8)clip_name)

//         animation_clips[index].direction = transmute(SliceDirection)clip_direction
//     }

//     return animator, animation_clips

// }



