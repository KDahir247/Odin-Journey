package journey

import "core:fmt"
import "core:os"
import "core:encoding/json"
import "core:hash"

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

SliceDirection :: enum i32{
    Horizontal = 0, 
    Vertical = 1, 
}

//Add offset len fir example we are playing a fire sprite sheet. the first 5 frame are the fire getting ingited
//

ClipFlag :: enum i32{
  Single = 0,
  Loop = 1,
  Sudden = 2,
  TilComplete = 3,
}

ClipFlags :: distinct bit_set[ClipFlag; i32]

//I think this is good. It would be nice to have animation speed
AnimationClip :: struct{
    half_bounds : []f32, //Stored as [(x, y), (x, y), (x, y), ....]
    len : i32,
    index : i32,
    direction : SliceDirection,
    flags :ClipFlags,
}

//Sprite Sheet Animator Structure
// We need to hold the clips 
// We want animation_duration_sec. How long each frame take 
// we want the current clip playing
// 

NewAnimator :: struct{
    clip_hash_map : map[u32]int, // key is the clip name hash, value is the index to fetch the clip
    previous_frame_index : int,
    clip_string_hash : u32,  //fnv32a
    slice_size_width : f32,
    slice_size_height : f32,
    animation_time : f32,
    animation_speed : f32,
    animation_duration_sec : f32,
}

LoadOperation :: enum{
    Runtime, // Load the content at runtime.
    Compiletime, // Load the content at compile time
}


//NOT THREAD SAFE
create_animator :: proc($clips_path : string, $op : LoadOperation, animation_speed : f32 = 1.0) -> (NewAnimator, []AnimationClip){
    @(static) global_offset : int
    
    animation_clips_bytes : []u8

    //TODO:khal different condition require different clip path since 
    {
        when op == LoadOperation.Compiletime{
            animation_clips_bytes = #load(clips_path)
        }else{
            animation_clips_bytes, _ = os.read_entire_file_from_filename(clips_path)
        }
    }
    
    animation_json, err := json.parse(animation_clips_bytes,json.Specification.JSON5, true)
    delete(animation_clips_bytes)

    defer if err == json.Error.None{
        json.destroy_value(animation_json)
    }

    animator : NewAnimator

    root := animation_json.(json.Object)

    //TODO: better way to hash.
    start_clip := root["starting_clip"].(json.String)
    animator.clip_string_hash = hash.fnv32a(transmute([]u8)start_clip)

    width := root["width"].(json.Float)
    height := root["height"].(json.Float)
    max_len := root["max_len"].(json.Float)
    max_index := root["max_index"].(json.Float)

    animator.slice_size_width = f32(width / max_len)
    animator.slice_size_height = f32(height / max_index)

    animator.animation_speed = animation_speed

    animator.animation_duration_sec = f32(root["animation_duration_seconds"].(json.Float))

    json_clips := root["clips"].(json.Array)

    animation_clips := make_slice([]AnimationClip, len(json_clips))
    animator.clip_hash_map = make_map(map[u32]int)

    for json_clip, index in json_clips{
        json_clip_object := json_clip.(json.Object)    
        
        clip_name := json_clip_object["name"].(json.String)
        animator.clip_hash_map[hash.fnv32a(transmute([]u8)clip_name)] = global_offset
        
        json_half_bounds := json_clip_object["half_bounds"].(json.Array)
        half_bounds := make_slice([]f32, len(json_half_bounds))

        for json_half_bound, index in json_half_bounds{
            half_bounds[index] = f32(json_half_bound.(json.Float))
        }

        animation_clips[index].half_bounds = half_bounds
        animation_clips[index].len = i32(json_clip_object["len"].(json.Integer))
        animation_clips[index].index = i32(json_clip_object["index"].(json.Integer))
        animation_clips[index].direction = transmute(SliceDirection)i32(json_clip_object["direction"].(json.Integer))

        wrapmode := transmute(ClipFlag)i32(json_clip_object["wrapmode"].(json.Integer))
        constraint := transmute(ClipFlag)i32(json_clip_object["constraint"].(json.Integer) + 2)

        animation_clips[index].flags = {wrapmode, constraint}

        global_offset += 1
    }

    return animator, animation_clips

}



