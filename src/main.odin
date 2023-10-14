package main

import "core:mem"
import "core:fmt"
import "core:sys/windows"
import "core:sync"
import "core:os"
import "core:math/linalg"
import "core:time"
import "core:slice"
import "core:encoding/json"

import "vendor:sdl2"
import "../journey"
import "vendor:stb/image"

loop_fn :: #type proc(arg : ^GameLoop)
event_fn :: #type proc(event : ^sdl2.Event)

GameLoop :: struct{
	fixed_deltatime : f32,
	delta_time : f32,
	elapsed_time : f32,
	elapsed_fixed_time : f32,
 
	maximum_frame_time : f32,
	update_per_second : f32,
 
	accumulated_time : f32,
	carry_over_time : f32,
 
	current_time : u32,
	previous_time : u32,
 
	terminate_next_iteration : bool,
}

GameFnDescriptor :: struct{

    update : loop_fn,
    fixed_update : loop_fn,
	on_animation : loop_fn,
    on_event : event_fn,

    //late_update : loop_fn,
}

next_frame_window :: proc(#no_alias game_loop : ^GameLoop, game_desc : GameFnDescriptor) -> bool{
	game_loop.current_time = sdl2.GetTicks()

    game_loop.delta_time = clamp(f32(game_loop.current_time - game_loop.previous_time) / 1000, 0, game_loop.maximum_frame_time)
    game_loop.elapsed_time += game_loop.delta_time

    game_loop.accumulated_time += (game_loop.delta_time + game_loop.carry_over_time)

    for game_loop.accumulated_time >= game_loop.fixed_deltatime{

		game_desc.fixed_update(game_loop)

        game_loop.elapsed_fixed_time += game_loop.fixed_deltatime
        game_loop.accumulated_time -= game_loop.fixed_deltatime

		game_loop.carry_over_time = game_loop.accumulated_time
    }

	game_desc.update(game_loop)
	game_desc.on_animation(game_loop)

	game_loop.previous_time = game_loop.current_time

    return !game_loop.terminate_next_iteration
}

start_looping_game :: proc(game_loop : ^GameLoop, event : ^sdl2.Event, game_descriptor : GameFnDescriptor){
    for next_frame_window(game_loop, game_descriptor){
        for sdl2.PollEvent(event){
            game_descriptor.on_event(event)
            game_loop.terminate_next_iteration = event.type == sdl2.EventType.QUIT
        }
    }
}

// If refresh rate is zero it will adapt the refresh rate with the monitor refresh rate (uses win call)
// linux it a bit tricker it need Xrandr extension, so this only works for windows. 
init_game_loop_window :: proc($refresh_rate : f32 , $refresh_rate_multiplier : f32 , $max_frame_time :f32) -> GameLoop{
    target_refresh_rate := refresh_rate

    when refresh_rate == 0{
        display_setting : windows.DEVMODEW
        windows.EnumDisplaySettingsW(nil,windows.ENUM_CURRENT_SETTINGS, &display_setting)
        target_refresh_rate = f32(display_setting.dmDisplayFrequency)
    }

    target_refresh_rate *= refresh_rate_multiplier
    fixed_deltatime := 1.0 / target_refresh_rate
    
    return GameLoop{
        delta_time = 0,
		previous_time = sdl2.GetTicks(),
        maximum_frame_time = max_frame_time,
        update_per_second = refresh_rate,
        fixed_deltatime = fixed_deltatime,
    }
}

//FNV-1a Hash
string_hash :: proc($path : string) -> uint{
	hash :uint=  0xcbf29ce484222325
	prime :uint= 0x100000001b3

	for char_rune in path{
		hash ~= cast(uint)(char_rune)
		hash *= prime
	}
	return hash
}

create_game_entity :: proc($tex_path : string, $shader_cache : u32, position : [2]f32, color : [4]f32, render_order : int) -> uint{
    world := cast(^journey.World)context.user_ptr
	unique_entity := uint(context.user_index)

	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)
	
	path_hash := string_hash(tex_path)
	if path_hash not_in resource.render_buffer.render_batch_groups{
		width :i32= 0
		height :i32= 0
		tex := image.load("resource/sprite/padawan/pad.png",&width,&height,nil,  4)

		tex_param : journey.TextureParam = journey.TextureParam{
			texture = tex,
			width = width,
			height = height,
			shader_cache = 0,
		}

		resource.render_buffer.render_batch_groups[path_hash] = journey.RenderBatchGroup{
			texture_param = tex_param,
			instances = make([dynamic]journey.RenderInstanceData),
		}
	}

	sprite_batch := &resource.render_buffer.render_batch_groups[path_hash]

	append(&sprite_batch.instances, journey.RenderInstanceData{
		transform = {
			2.0 , 0.0, 0.0, position[0],
			0.0, 2.0, 0.0, position[1],
			0.0, 0.0, 2.0, 0.0,
			0.0, 0.0, 0.0, 1.0,
		},

		src_rect = {
			0.0,
			0.0,
			f32(sprite_batch.texture_param.width),
			f32(sprite_batch.texture_param.height),
		},
		color = color,
		flip_bit = {1,1},
		order_index = render_order,
	})
	
	game_entity := journey.create_entity(world)

	journey.add_soa_component(world, game_entity, journey.RenderInstance{
		hash = path_hash,
		instance_index = len(sprite_batch.instances) - 1,
	})

	sync.atomic_store_explicit(&resource.render_buffer.changed_flag, true, sync.Atomic_Memory_Order.Relaxed)

	return game_entity
}

//////////////////////////////////////////////////////////////////////

event_update :: proc(event : ^sdl2.Event){

	world := cast(^journey.World)context.user_ptr
	unique_entity := uint(context.user_index)
	controller := journey.get_soa_component(world, unique_entity, journey.GameController)

	safe_keycode_index := min(int(event.key.keysym.sym), len(controller.key_buffer) - 1)

	if event.type == sdl2.EventType.KEYDOWN {
		press_value := controller.sensitvity * 0.02
		controller.key_buffer[safe_keycode_index] = min(controller.key_buffer[safe_keycode_index] + press_value, 1)

	}else if event.type == sdl2.EventType.KEYUP{

		//TODO: khal we later want to decrement this slowly rather the snaping to zero
		controller.key_buffer[safe_keycode_index] = 0
	}
}

fixed_update :: proc(global : ^GameLoop){

	// TODO:khal add kinematic and rigidbody implementation for future, since this implementation has constraint that we are breaking.
	// Look good, but not accurate. 

    world := cast(^journey.World)context.user_ptr
	unique_entity := uint(context.user_index)
	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)
	game_controller := journey.get_soa_component(world, unique_entity, journey.GameController)

	acceleration_integrate_query := journey.query(world, journey.Mass, journey.AccumulatedForce, journey.Acceleration, 8)
	force_query := journey.query(world, journey.Mass, journey.AccumulatedForce, journey.Velocity, 8)

    velocity_integrate_query := journey.query(world, journey.Velocity, journey.Acceleration, 8)

	//currently physics loop only needs accumulated force this will be add on
	fixed_update_query := journey.query(world, journey.AccumulatedForce)

	for component_storage, index in journey.run(&force_query){
		mutable_component_storage := component_storage

		//Assuming that the inverse mass is not zero if so then we have a divide by zero exception.

		mass := 1.0 / mutable_component_storage.component_a[index].val

		//Gravitation force
		{
			gravitation_force := journey.GRAVITY * mass 
			mutable_component_storage.component_b[index].y += gravitation_force
		}

		//Drag force
		{
			mutable_component_storage.component_b[index].y += (-0.2 *component_storage.component_c[index].y* mass)//(component_storage.component_c[index].y *component_storage.component_c[index].y * -0.1)
		}

		// Friction force. We will only calculate horizontal friction force for the game.
		{
			//N = m*g
			//if surface is inclined then the formula would be N = m * g *cos(theta)
			normal_force := mass * journey.GRAVITY
			// This 0.65 magic number will change the friction coefficent will be retrieve by the collided ground fricition coefficient
			// So a ice tile will have a smaller coefficient and a grass tile will have a larger coefficient. till then it will be 0.65 
			friction := normal_force * 0.65
			friction_force := -component_storage.component_c[index].x * friction
			mutable_component_storage.component_b[index].x += friction_force
		}

	}

	//Simple Physics Integrate	
	for component_storage, index in journey.run(&acceleration_integrate_query){
		mutable_component_storage := component_storage

		//a = f/m
		acceleration_step_x := component_storage.component_a[index].val * component_storage.component_b[index].x
		acceleration_step_y := component_storage.component_a[index].val * component_storage.component_b[index].y

		mutable_component_storage.component_c[index].x = acceleration_step_x
		mutable_component_storage.component_c[index].y = acceleration_step_y

		mutable_component_storage.component_b[index] = {}
	}

	for component_storage, index in journey.run(&velocity_integrate_query){
		sprite := journey.get_soa_component(world, component_storage.entities[index], journey.RenderInstance)
		sprite_batch := resource.render_buffer.render_batch_groups[sprite.hash]

		mutable_component_storage := component_storage

		sprite_batch.instances[sprite.instance_index].transform[0,3] += (component_storage.component_a[index].x * global.fixed_deltatime)
		sprite_batch.instances[sprite.instance_index].transform[1,3] += (component_storage.component_a[index].y * global.fixed_deltatime)

		mutable_component_storage.component_a[index].x += (component_storage.component_b[index].x * global.fixed_deltatime)
		mutable_component_storage.component_a[index].y += (component_storage.component_b[index].y * global.fixed_deltatime)
	}
	//

	//Physic Solver




	//

	//Fixed Loop
	for component_storage, index in journey.run(&fixed_update_query){
		mutable_component_storage := component_storage

		//Only adding a horizontal add force
		player_input_x := game_controller.key_buffer[sdl2.Keycode.A] - game_controller.key_buffer[sdl2.Keycode.D]
		//magic number 4000 for placeholder for player movement.
		mutable_component_storage.component_a[index].x += player_input_x * 200
	}
	//
}

update :: proc(global : ^GameLoop){
	world := cast(^journey.World)context.user_ptr
	
	unique_entity := uint(context.user_index)
	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)
	game_controller := journey.get_soa_component(world, unique_entity, journey.GameController)

	//TODO:khal better component
	sprite_flip_query := journey.query(world, journey.Velocity)

	for component_storage, index in journey.run(&sprite_flip_query){
		sprite := journey.get_soa_component(world, component_storage.entities[index], journey.RenderInstance)
		sprite_batch := resource.render_buffer.render_batch_groups[sprite.hash]

		if component_storage.component_a[index].x > 0{
			sprite_batch.instances[sprite.instance_index].flip_bit[0] = 1
		}else if component_storage.component_a[index].x < 0{
			sprite_batch.instances[sprite.instance_index].flip_bit[0] = 0
		}
	}
}

on_animation :: proc(global : ^GameLoop){

    world := cast(^journey.World)context.user_ptr
	
	unique_entity := uint(context.user_index)
	// Cache texture and shader and render data to send to render thread
	resource := journey.get_soa_component(world, unique_entity, journey.ResourceCache)

	anim_sprite_query := journey.query(world, journey.Animator)

	for component_storage, index in journey.run(&anim_sprite_query){
		mutable_component_storage := component_storage
		sprite := journey.get_soa_component(world, component_storage.entities[index], journey.RenderInstance)
		
		//TODO:khal do better implementation
		if journey.has_soa_component(world, component_storage.entities[index], journey.Velocity){
			velocity := journey.get_soa_component(world, component_storage.entities[index], journey.Velocity)
			mutable_component_storage.component_a[index].current_clip = int(linalg.abs(velocity.x) >= 0.5)
			
		}
		
		animator := component_storage.component_a[index]

		current_clip := animator.clips[animator.current_clip]

		normalized_time := global.elapsed_time / animator.animation_duration_sec

		y :=current_clip.index * current_clip.height
		x := (int(normalized_time) % current_clip.len) * current_clip.width
		
		sprite_batch := resource.render_buffer.render_batch_groups[sprite.hash]
		sprite_batch.instances[sprite.instance_index].src_rect = {
			f32(x), f32(y), f32(current_clip.width), f32(current_clip.height),
		} 
	}
}

main ::  proc()  {

	track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

	////////////////////// Game Initialize /////////////////////////

	sdl2_event : sdl2.Event
	window_info : sdl2.SysWMinfo 

	//temp solution
	resource : journey.ResourceCache = journey.ResourceCache{
		render_buffer = new(journey.RenderBatchBuffer),
	}
	resource.render_buffer.render_batch_groups = make(map[uint]journey.RenderBatchGroup)

	game_controller := journey.GameController{
		key_buffer = make([]f32, 128),
		sensitvity = 1.0,
		dead = 0.001,
		gravity = 1.0,
		rcp_max_threshold = 0.01,
	}

	game_loop := init_game_loop_window(0, 1, journey.MAX_DELTA_TIME)

	world := journey.init_world()
	context.user_ptr = world

	journey.register(world, journey.Animator)

	journey.register(world, journey.Velocity)
	journey.register(world, journey.Acceleration)
	journey.register(world, journey.Mass)
	journey.register(world, journey.AccumulatedForce)
	journey.register(world, journey.Friction)
	journey.register(world, journey.Restitution)
	journey.register(world, journey.RenderInstance)
	

	journey.register(world, journey.ResourceCache)
	journey.register(world, journey.GameController)

	sdl2.InitSubSystem(sdl2.InitFlags{sdl2.InitFlag.EVENTS})

	window := sdl2.CreateWindow(
		"MyGame",
		sdl2.WINDOWPOS_CENTERED, 
		sdl2.WINDOWPOS_CENTERED,
		1045, // 29 * 36 + 1 (WIDTH + CELL SIZE + OFFSET)
		613, // 17 * 36 + 1 (HEIGHT + CELL SIZE + OFFSET)
		sdl2.WindowFlags{
			sdl2.WindowFlag.SHOWN,
			sdl2.WindowFlag.RESIZABLE,
			sdl2.WindowFlag.ALLOW_HIGHDPI,
		},
	)

	sdl2.GetWindowWMInfo(window, &window_info)

	render_thread := journey.create_renderer(journey.RenderBackend.DX11,window_info.info.win.window, resource.render_buffer)

	//TODO: khal this will change when resource is implement in journey_ecs
	context.user_index = int(journey.create_entity(world))
	journey.add_soa_component(world, uint(context.user_index), resource)
	journey.add_soa_component(world, uint(context.user_index), game_controller)
	//

	defer{	
		journey.stop_renderer(render_thread)

		journey.deinit_world(world)
		context.user_ptr = nil

		{
			delete(game_controller.key_buffer)
		
			for _,group in resource.render_buffer.render_batch_groups{
				delete(group.instances)
			}

			delete(resource.render_buffer.render_batch_groups)
			free(resource.render_buffer)
		}

		sdl2.DestroyWindow(window)
		sdl2.Quit()

		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		} 
		mem.tracking_allocator_destroy(&track)
	}
	////////////////////////////////////////////////////////////////////

	///////////////////////// Game Start ///////////////////////////////

	player_entity_1 := create_game_entity("resource/sprite/padawan/pad.png", 0, {0,0},{0.0, 0.0, 0.0, 0.0}, 4)
	player_entity_2 := create_game_entity("resource/sprite/padawan/pad.png", 0, {0,0}, {0.0, 0.0, 0.0, 0.0}, 2)

	//TODO:khal proof of implementation flesh it out.
	data,_ := os.read_entire_file_from_filename("resource/animation/player_anim.json")
	defer delete(data)
	player_anim : journey.Animator
	json.unmarshal(data, &player_anim)

	journey.add_soa_component(world, player_entity_1, player_anim)
	journey.add_soa_component(world, player_entity_2, player_anim)

	journey.add_soa_component(world, player_entity_1, journey.Velocity{0, 0})
	journey.add_soa_component(world,player_entity_1, journey.Acceleration{0,0})
	journey.add_soa_component(world, player_entity_1, journey.AccumulatedForce{})
	journey.add_soa_component(world, player_entity_1, journey.Mass{0.1})
	//

	///////////////////////////////////////////////////////////////////

	///////////////////////// Game Loop ///////////////////////////////
	start_looping_game(&game_loop,&sdl2_event, GameFnDescriptor{
		update = update,
		fixed_update = fixed_update,
		on_animation = on_animation,
		on_event = event_update,
	})
	///////////////////////// Game Loop ///////////////////////////////
}
