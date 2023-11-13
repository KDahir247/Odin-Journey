package journey

import "core:fmt"
import "core:os"
import "core:encoding/json"

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

SliceDirection :: enum int{
    Horizontal = 0, 
    Vertical = 1, 
}

WrapMode :: enum int{
    PlayOnceFirst = 0,
    Loop = 1, 
    PingPong = 2,
    PlayOnceLast = 3,
}

Constraint :: enum int{
    Sudden = 1,
    TilComplete = 2,
}

AnimationClip :: struct{
    len : []int, // []int Index to slice is the row. The value is how much column it takes
    x_half_bounds : []f32,
    y_half_bounds : []f32,
    width : f32,
    height : f32,
    index : int, // the start row
    animation_speed : int,
    constraint : Constraint,
    direction : SliceDirection,
    wrapmode :WrapMode,
}


//Sprite Sheet Animator Structure
// We need to hold the clips 
// We want animation_duration_sec. How long each frame take 
// we want the current clip playing
// 

NewAnimator :: struct{
    clips_indices : map[string]int, //used to index the clip slice
    target_index : int, //next clip to play 
    min_index : int, //min bound for the the slice of clips
    max_index : int, //max bound for the slice of clips
    animation_duration_sec : f32,
    animation_speed : f32,
}

LoadOperation :: enum{
    Runtime, // Load the content at runtime.
    Compiletime, // Load the content at compile time
}


//NOT THREAD SAFE
create_animator :: proc($clips_path : string, clips : [$N]string, $op : LoadOperation, clip_duration_per_sec : f32 = 0.1, animation_speed : f32 = 1){
    @(static) global_offset : i32
    
    animation_clips_bytes : []u8
    valid_file := true

    //TODO:khal different condition require different clip path since 
    when op == LoadOperation.Compiletime{
        animation_clips_bytes = #load(clips_path)
    }else{
        animation_clips_bytes, valid_file = os.read_entire_file_from_filename(clips_path)
    }
    
    defer if valid_file{
        delete(animation_clips_bytes)
    }

    animation_json,err := json.parse(animation_clips_bytes,json.Specification.JSON5, true)

    defer if err == json.Error.None{
        json.destroy_value(animation_json)
    }

    animator : NewAnimator

    root := animation_json.(json.Object)

 
    fmt.println(size_of(NewAnimator), align_of(NewAnimator))
    fmt.println(size_of(AnimationClip), align_of(AnimationClip))


}



