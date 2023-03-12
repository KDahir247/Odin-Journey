package game_context
import "../ecs"
import "../mathematics"
import "../container"

import "core:encoding/json"
import "core:os"

create_animator :: proc(animation_speed : f32, clips : [$E]container.AnimationClip) -> uint{
	ctx := cast(^Context) context.user_ptr

    dyn_clips := make(map[string]container.AnimationClip,E)

    #no_bounds_check{
        for index in 0..<E{
            name := clips[index].name
            dyn_clips[name] = clips[index]
        }
    }

    animator : container.Animator
    animator_entity := ecs.create_entity(&ctx.world)

    animator.animation_speed = animation_speed
    animator.previous_frame = 0
    animator.animation_time = 0
    animator.clips = dyn_clips

    ecs.add_component_unchecked(&ctx.world, animator_entity, animator)
    return uint(animator_entity)
}

set_animation_clip_and_reset :: #force_inline proc "contextless" (animator : ^container.Animator, name : string, speed : f32){
    animator.current_animation = name
    animator.animation_speed = speed
    animator.previous_frame = 0
}

set_animation_clip :: #force_inline proc "contextless"(animator : ^container.Animator, name : string, speed : f32){
    animator.current_animation = name
    animator.animation_speed = speed
}

animation_clip_finished :: #force_inline proc (animator : ^container.Animator) -> bool{
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