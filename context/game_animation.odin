package game_context
import "../ecs"
import "../mathematics"
import "../container"

import "core:encoding/json"
import "core:os"

//TODO: animation file should support the following
// "index" (the row the animation strip is in)
// "num_slice" (how much column the animation has aka. the number of clips)
// "offset_slice" (how much column should be be skipped in the sprite sheet)
// "width" (the sprite width for the animation clip)
// "height" (the sprite height for the animation clip)
// "loop" (should the animation loop?)
// "carry_over" (if the animation continues over from the index to the next index what index is it carried over to and how much column does it take up.)
// "animation_speed" (how the speed the animation should transition for this clip LOCAL only affect the current clip, the animator speed parameter is GLOBAL affect all the clip the same)
// "order" (If the sprite sheet is horizontal the order will be 0 otherwise if the sprite sheet is 1 then it is vertical)

create_animator :: proc(animation_speed : f32, clips : [$E]container.AnimationClip) -> uint{
	ctx := cast(^Context) context.user_ptr

    dyn_clips := make(map[string]container.AnimationClip,E)

    #no_bounds_check{
        for index in 0..<E{
            name := clips[index].name
            dyn_clips[name] = clips[index]
        }
    }

    animator_entity := ecs.create_entity(ctx.world)

    animator := container.Animator{
        "",
        0,
        0,
        animation_speed,
        dyn_clips,
    }

    ecs.add_component_unchecked(ctx.world, animator_entity, animator)
    return uint(animator_entity)
}

set_animation_clip_and_reset :: #force_inline proc "contextless" (animator : ^container.Animator, name : string, condition : bool, speed : f32){
    interal_animation := [2]string{
        animator.current_animation,
        name,
    }

    #no_bounds_check{
        animator.current_animation = interal_animation[int(condition)]
    }

    animator.animation_speed = speed
    animator.previous_frame = 0
}

set_animation_clip :: #force_inline proc "contextless"(animator : ^container.Animator, name : string, condition : bool, speed : f32){
    interal_animation := [2]string{
        animator.current_animation,
        name,
    }
    
    #no_bounds_check{
        animator.current_animation = interal_animation[int(condition)]
    }
    
    animator.animation_speed = speed
}

animation_clip_finished :: #force_inline proc "contextless"(animator : ^container.Animator) -> bool{
    #no_bounds_check{
        current_animation := animator.clips[animator.current_animation]
        return !current_animation.loopable && current_animation.len - 1  == animator.previous_frame
    }
}

create_animation_clips :: proc($path : string, clips_json : [$E]string) -> [E]container.AnimationClip{
    animation_clips : [E]container.AnimationClip

    animation_data,_ := os.read_entire_file_from_filename(path)
    anim_json, _ := json.parse(animation_data, json.DEFAULT_SPECIFICATION, true)

    defer delete(animation_data)
    defer json.destroy_value(anim_json)

    root := anim_json.(json.Object)

    #no_bounds_check{
        for index in 0..<E{
            animation := clips_json[index]
            animation_detail := root[animation].(json.Object)
            
            clip : container.AnimationClip
            clip.name = animation
            
            clip.dimension = mathematics.Vec2i{
                int(animation_detail["width"].(json.Integer)),
                int(animation_detail["height"].(json.Integer)),
            }

            clip.len = int(animation_detail["num_slice"].(json.Integer))
            clip.pos = int(animation_detail["index"].(json.Integer))
            clip.loopable = animation_detail["loop"].(json.Boolean)

            animation_clips[index] = clip
        }
    }

    return animation_clips
}