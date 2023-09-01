package journey

import "core:slice"
import "core:runtime"
import "core:fmt"
import "core:intrinsics"
import "core:mem"


////////////////////////////// ECS Resource ////////////////////////////////////
Resources :: struct{
    //
}

///////////////////////////////////////////////////////////////////////////////


// u16 maximum value, since currently we split a u32 in half hi u16 is id lo u16 is version
DEFAULT_MAX_ENTITY :: 65535
DEFAULT_COMPONENT_SPARSE :: 32
DEFAULT_GROUP :: 32

////////////////////////////// ECS Utility ////////////////////////////////////

//return 0 for all negative and 1 for all postive and zero.
@(private)
normalize_value :: #force_inline proc "contextless" (val : int) -> int{
    return (val >> 63) + 1 //arithemtic shift
}

////////////////////////////////////////////////////////////////////////////

////////////////////////// ECS World ////////////////////////////////////

ComponentGroup :: struct{
    component_types : []typeid,   
}

World :: struct{
    entities_stores : EntityStore,
    component_stores : ComponentStore,
}

init_world :: proc(entity_capacity : int = DEFAULT_MAX_ENTITY, component_capacity : int = 2048) -> ^World{
    world := new(World)

    world.entities_stores = init_entity_store(entity_capacity)
    world.component_stores = init_component_store(component_capacity)

    return world
}

@(deferred_out=deinit_world)
scope_init_world :: proc(entity_capacity : int = DEFAULT_MAX_ENTITY) -> ^World{
   return init_world(entity_capacity)
}

deinit_world :: proc(world : ^World){
    deinit_entity_store(&world.entities_stores)
    deinit_component_store(&world.component_stores)
	free(world)
}

register_as_subgroup :: proc(world : ^World, component_groups : ..ComponentGroup, capacity : u32 = DEFAULT_COMPONENT_SPARSE){
    internal_register_sub_group(&world.component_stores, component_groups, capacity)  
}

register_as_group :: proc(world : ^World, component_types : ..typeid, capacity : u32 = DEFAULT_COMPONENT_SPARSE){
    //TODO:khal handle case where the user put only one type if so then it is just a normal register
    internal_register_group(&world.component_stores,component_types,0,capacity)
}

register :: proc(world : ^World, $component_type : typeid, capacity : u32 = DEFAULT_COMPONENT_SPARSE){
    internal_register_component(&world.component_stores, component_type, capacity)
}

set_component :: proc(world : ^World, entity : u32, component : $T){
    if intrinsics.expect(internal_entity_is_alive(&world.entities_stores, entity), true){
        
        sparse_id := world.component_stores.component_info[T].sparse_index
        internal_sparse_put(&world.component_stores.component_sparse[sparse_id], entity, component)

        internal_increment_version(&world.entities_stores, entity)
    }
}

get_component :: proc(world : ^World, entity : u32, $component : typeid) -> ^component{
    desired_component : ^component = nil

    if intrinsics.expect(internal_entity_is_alive(&world.entities_stores, entity), true){
        
        sparse_id := world.component_stores.component_info[component].sparse_index
        desired_component = internal_sparse_get(&world.component_stores.component_sparse[sparse_id],entity, component)

        internal_increment_version(&world.entities_stores, entity)
    }

    return desired_component
}

get_entities_with_component :: proc(world : ^World, component_type : typeid) -> []u32{
    sparse_id := world.component_stores.component_info[component_type].sparse_index
    return internal_sparse_fetch_entities(&world.component_stores.component_sparse[sparse_id])
} 

get_components_with_id :: proc(world : ^World, $component : typeid) -> []component{
    sparse_id := world.component_stores.component_info[component].sparse_index
    return internal_sparse_fetch_components(&world.component_stores.component_sparse[sparse_id], component)
}

add_component :: proc(world : ^World, entity : u32, component : $T){
    if intrinsics.expect(internal_entity_is_alive(&world.entities_stores, entity), true){
        internal_add_component_group(&world.component_stores, entity, component)
        internal_increment_version(&world.entities_stores, entity)
    }
}

remove_component :: proc(world : ^World, entity : u32, $component_type : typeid){
    if intrinsics.expect(internal_entity_is_alive(&world.entities_stores, entity), true){
        internal_remove_component_group(&world.component_stores, entity, component_type)
        internal_increment_version(&world.entities_stores, entity)
    }
}

query :: proc(world : ^World,  query_desc : ..typeid) -> []u32{
    

    entity_list := get_entities_with_component(world,query_desc[0])

    for entity in entity_list{

    }

    panic("Not implemented yet!")
}

create_entity :: proc(world : ^World) -> u32{
    return internal_create_entity(&world.entities_stores)
}


remove_entity :: proc(world : ^World, entity : u32){
    panic("Not implemented yet!")
}

///////////////////////////////////////////////////////////////////

//////////////////////// Entity Store /////////////////////////////

EntityStore :: struct { //56
    entities : [dynamic]u32,
    available_to_recycle : int,
    next_recycle : u32,
}

@(private)
init_entity_store :: proc(capacity : int) -> EntityStore{
    entity_store := EntityStore{
        entities = make([dynamic]u32, 0,capacity),
        available_to_recycle = 0,
        next_recycle = 0,
    }
    
    return entity_store
}

@(private)
deinit_entity_store :: proc(entity_store : ^EntityStore){
    delete_dynamic_array(entity_store.entities)
    entity_store.available_to_recycle = 0
    entity_store.next_recycle = 0
}
@(private)
internal_create_entity :: proc(entity_store : ^EntityStore) -> u32{
    entity : u32 = entity_store.next_recycle

   if entity_store.available_to_recycle > 0{

    previous_entity_detail := entity_store.entities[entity]
    entity_store.entities[entity] = (entity + 1)  << 16

    entity_store.available_to_recycle -= 1

    entity_store.next_recycle = previous_entity_detail >> 16

   }else{
    entity = u32(len(entity_store.entities))

    append(&entity_store.entities, (entity + 1) << 16)
   }

   return entity
}

@(private)
internal_destroy_entity :: proc(entity_store : ^EntityStore, entity : u32) #no_bounds_check{
    entity_store.entities[entity] += 1
    entity_store.available_to_recycle += 1

    entity_store.next_recycle = entity 
}

@(private)
internal_entity_is_valid :: #force_inline proc(entity_store : ^EntityStore, entity : u32) -> int{
    return u32(len(entity_store.entities) -1) > entity ? 1 : 0
}

@(private)
internal_entity_is_alive :: #force_inline proc(entity_store : ^EntityStore, entity : u32) -> bool #no_bounds_check{
    entity_detail := entity_store.entities[entity]
    return(entity_detail & 0xFF) == (entity_detail >> 8) & 0xFF
}

@(private)
internal_increment_version :: #force_inline proc(entity_store : ^EntityStore, entity : u32){
    entity_store.entities[entity] += 257

    if entity_store.entities[entity] & 0xFF == 0xFF{
        entity_store.entities[entity] &= 0xFF_FF_00_00
    }
}
/////////////////////////////////////////////////////////////////////

/////////////////////////// ECS Group ///////////////////////////////

Group :: struct{
    indices : []int, // generic if it is a single group then it is a sparse_indices otherwise it is a group indicies....
    start : int,
}

//////////////////////////////////////////////////////////////////

///////////////////// Component Store ///////////////////////////

ComponentInfo :: struct{
    group_indices : [3]int,
    sparse_index : int,
}

ComponentStore :: struct{ //112
    component_info : map[typeid]ComponentInfo,
    component_sparse : [dynamic]ComponentSparse, 
    groups : [dynamic]Group,
}

@(private)
init_component_store :: proc(capacity : int) -> ComponentStore{
    component_store := ComponentStore{
        component_info = make_map(map[typeid]ComponentInfo,capacity),
        component_sparse = make([dynamic]ComponentSparse, 0, capacity),
        groups = make([dynamic]Group, 0, DEFAULT_GROUP),
    }

    nil_group := Group{
        indices = []int{},
        start=0,
    }

    append(&component_store.groups, nil_group)

    return component_store
}

@(private)
internal_register_sub_group :: proc(component_store : ^ComponentStore, component_groups : []ComponentGroup, capacity : u32 = DEFAULT_COMPONENT_SPARSE){
    sub_group : Group

    component_group_start := len(component_store.groups)
    component_group_end := component_group_start + len(component_groups)

    group_indices := make_slice([]int, len(component_groups))

    for group_index in component_group_start..<component_group_end{
        index := group_index - component_group_start
        group_indices[index] = group_index 
    }

    for component_group in component_groups{
        internal_register_group(component_store, component_group.component_types, component_group_end, capacity)
    }  

    sub_group.indices = group_indices

    append(&component_store.groups, sub_group)

}

@(private)
internal_register_group :: proc(component_store : ^ComponentStore,component_types : []typeid,sub_group_index :int, capacity : u32){
    group : Group

    group_sparse_indices := make_slice([]int, len(component_types))

    group_index := len(component_store.groups)

    for component_type, index in component_types{
        internal_register_component(component_store, component_type, capacity)

        component_info := &component_store.component_info[component_type]

        group_sparse_indices[index] = component_info.sparse_index
        component_info^.group_indices[1] = group_index
        component_info^.group_indices[2] = sub_group_index
    }

    group.indices = group_sparse_indices

    append(&component_store.groups, group)
}

@(private)
internal_register_component :: proc(component_store : ^ComponentStore, component_type : typeid, capacity : u32){
    _, valid := component_store.component_info[component_type]

    if !valid{
        component_store.component_info[component_type] = ComponentInfo{
            sparse_index = len(component_store.component_sparse),
        }

        append(&component_store.component_sparse, init_component_sparse(component_type, capacity))
    }
}

@(private)
internal_add_component_group :: proc(component_store : ^ComponentStore, entity : u32, component : $T){
    component_info := component_store.component_info[typeid_of(T)]
    
    group := component_store.groups[component_info.group_indices[1]]
    sub_group := component_store.groups[component_info.group_indices[2]]
    
    group_index := normalize_value(len(group.indices) - 1)
    sub_group_index := normalize_value(len(sub_group.indices) - 1)

    internal_sparse_push(&component_store.component_sparse[component_info.sparse_index], entity, component)

    //////////////////////////// Grouping ////////////////////////////
    for group_sparse_id in group.indices{
        group_index &= internal_sparse_has(&component_store.component_sparse[group_sparse_id], entity)
    }

    target_group_index := component_info.group_indices[group_index]
    target_group := component_store.groups[target_group_index]

    for group_sparse_id in target_group.indices{
        group_sparse := component_store.component_sparse[group_sparse_id]

        if internal_sparse_get_index(&group_sparse, entity) > group.start{
            group_start_entity := internal_sparse_index_entity(&group_sparse, group.start)

            internal_sparse_swap(&group_sparse,group_start_entity, entity, size_of(T))
        }
    }
    //////////////////////////////////////////////////////////////////

    //////////////////////// Sub Grouping ////////////////////////////
    for group_id in sub_group.indices{
        for group_sparse_id in component_store.groups[group_id].indices{
            sub_group_index &= internal_sparse_has(&component_store.component_sparse[group_sparse_id], entity)
        }
    }

    target_sub_group_index := component_info.group_indices[sub_group_index << 1]
    target_sub_group := component_store.groups[target_sub_group_index]

    for group_id in target_sub_group.indices{
        group_sparse_indices := component_store.groups[group_id].indices
        
        for group_sparse_id in group_sparse_indices{
            group_sparse := component_store.component_sparse[group_sparse_id]

            if internal_sparse_get_index(&group_sparse, entity) > sub_group.start{
                group_sub_start_entity := internal_sparse_index_entity(&group_sparse, sub_group.start)
    
                internal_sparse_swap(&group_sparse,group_sub_start_entity, entity, size_of(T))
            }
        }
    }
    //////////////////////////////////////////////////////////////////

    component_store.groups[component_info.group_indices[1]].start += group_index
    component_store.groups[component_info.group_indices[2]].start += sub_group_index

}

@(private)
internal_remove_component_group :: proc(component_store : ^ComponentStore, entity : u32, $component_type : typeid){
    component_info := component_store.component_info[component_type]
    
    group := component_store.groups[component_info.group_indices[1]]
    sub_group := component_store.groups[component_info.group_indices[2]]

    group_index := normalize_value(len(group.indices) - 1)
    sub_group_index := normalize_value(len(sub_group.indices) - 1)

    //////////////////////// Sub Grouping ////////////////////////////

    for group_id in sub_group.indices{
        group_sparse_indices := component_store.groups[group_id].indices

        for group_sparse_id in group_sparse_indices{
            sub_group_index &= internal_sparse_has(&component_store.component_sparse[group_sparse_id], entity)
        }
    }

    target_sub_group_index := component_info.group_indices[sub_group_index << 1]
    target_sub_group := component_store.groups[target_sub_group_index]

    for group_id in target_sub_group.indices{
        group_sparse_indices := component_store.groups[group_id].indices
        for group_sparse_id in group_sparse_indices{
            group_sparse := component_store.component_sparse[group_sparse_id]
            swap_entity := internal_sparse_index_entity(&group_sparse, sub_group.start - 1)
        
            internal_sparse_swap(&group_sparse, swap_entity, entity, size_of(component_type))
        }
    }
    //////////////////////////////////////////////////////////////////

    //////////////////////////// Grouping ////////////////////////////
    for group_sparse_id in group.indices{
        group_index &= internal_sparse_has(&component_store.component_sparse[group_sparse_id], entity)
    }

    target_group_index := component_info.group_indices[group_index]
    target_group := component_store.groups[target_group_index]

    for group_sparse_id in target_group.indices{
        group_sparse := component_store.component_sparse[group_sparse_id]

        swap_entity := internal_sparse_index_entity(&group_sparse, group.start - 1)
        internal_sparse_swap(&group_sparse, swap_entity, entity, size_of(component_type))
    }
    //////////////////////////////////////////////////////////////////

    component_store.groups[component_info.group_indices[1]].start -= group_index
    component_store.groups[component_info.group_indices[2]].start -= sub_group_index

    internal_sparse_remove(&component_store.component_sparse[component_info.sparse_index], entity, component_type)
}


@(private)
deinit_component_store :: proc(component_store : ^ComponentStore){
    delete(component_store.component_info)

    for comp in component_store.component_sparse{
        free(comp.entity_blob)
        free(comp.component_blob)
        free(comp.sparse_blob)
    }

    delete(component_store.component_sparse)

    for group in component_store.groups{
        delete(group.indices)
    }

    delete(component_store.groups)
}

ComponentSparse :: struct { 
    entity_blob : rawptr,
    component_blob : rawptr, 
    cap : u32,
    len : u32,  
    sparse_blob : rawptr, 
}

@(private)
init_component_sparse :: proc(type : typeid, dense_capacity : u32) -> ComponentSparse{
    component_blob,_ := mem.alloc(size_of(type) * int(dense_capacity))
    entity_blob,_ := mem.alloc(int(dense_capacity) << 2)
    //65535 << 3 == 524,280 we do a left shift of three which basically mean 65535 * 8 (int sizeof is 8 of course this is platform specific)
    sparse_blob,_ := mem.alloc(524280)
    runtime.memset(sparse_blob, -1, 524280)

    return ComponentSparse{
        sparse_blob = sparse_blob,
        entity_blob = entity_blob,
        component_blob = component_blob,
        len = 0,
        cap = dense_capacity,
    }
}

@(private)
internal_sparse_get_index :: #force_inline proc(component_sparse : ^ComponentSparse, entity : u32) -> int{
    return ([^]int)(component_sparse.sparse_blob)[entity]
}

@(private)
internal_sparse_put_index :: #force_inline proc(component_sparse : ^ComponentSparse, entity : u32, value : int) {
    sparse_ptr : ^int = ([^]int)(component_sparse.sparse_blob)[entity:]
    sparse_ptr^ = value
}

@(private)
internal_sparse_push :: proc(component_sparse : ^ComponentSparse, entity : u32, component : $T) #no_bounds_check{
    local_component := component
    local_entity := entity

    dense_id := internal_sparse_get_index(component_sparse, entity)
    has_mask := internal_sparse_has(component_sparse, entity)
    incr_mask := (1.0 -  has_mask)

    dense_index := (int(component_sparse.len) * incr_mask) + (dense_id * has_mask)

    if component_sparse.cap == component_sparse.len{
        capacity := int(component_sparse.cap)
        new_capacity := capacity << 1

        new_entity_blob,_ := mem.resize(component_sparse.entity_blob, capacity, new_capacity)
        new_component_blob,_ := mem.resize(component_sparse.component_blob, capacity, new_capacity)

        component_sparse.entity_blob = new_entity_blob
        component_sparse.component_blob = new_component_blob

        component_sparse.cap = u32(new_capacity)
    }

    internal_sparse_put_index(component_sparse, entity, dense_index)

    comp_ptr :^T= ([^]T)(component_sparse.component_blob)[dense_index:]
    ent_ptr :^u32= ([^]u32)(component_sparse.entity_blob)[dense_index:]
    
    comp_ptr^ = local_component
    ent_ptr^ = local_entity

    component_sparse.len += u32(incr_mask)
}

@(private)
internal_sparse_get :: proc(component_sparse : ^ComponentSparse, entity : u32, $component_type : typeid) -> ^component_type {
    dense_index := internal_sparse_get_index(component_sparse, entity)
    return &([^]component_type)(component_sparse.component_blob)[dense_index]
}

@(private)
internal_sparse_index_component :: #force_inline proc(component_sparse : ^ComponentSparse, index : int, $component_type : typeid) -> component_type{
    return ([^]component_type)(component_sparse.component_blob)[index]
} 

@(private)
internal_sparse_index_entity :: #force_inline proc(component_sparse : ^ComponentSparse, index : int) -> u32{
    return ([^]u32)(component_sparse.entity_blob)[index]
}

@(private)
internal_sparse_index_put_component :: #force_inline proc(component_sparse : ^ComponentSparse, index : int, component : $T){
    component_ptr : ^T = ([^]T)(component_sparse.component_blob)[index:]
    component_ptr^ = component
}

@(private)
internal_sparse_index_put_entity :: #force_inline proc(component_sparse : ^ComponentSparse, index : int, entity : u32){
    entity_ptr : ^u32 = ([^]u32)(component_sparse.entity_blob)[index:]
    entity_ptr^ = entity
}

@(private)
internal_sparse_put :: proc(component_sparse : ^ComponentSparse, entity : u32, component : $T) {
    dense_id := component_sparse.sparse[entity.id]
    comp_ptr :^T= ([^]T)(component_sparse.component_blob)[dense_id:] 
    comp_ptr^ = component
}

@(private)
internal_sparse_remove :: proc(component_sparse : ^ComponentSparse, entity : u32, $component_type : typeid) -> component_type{
    dense_id := internal_sparse_get_index(component_sparse, entity)
        
    component_sparse.len -= 1

    last_entity := ([^]u32)(component_sparse.entity_blob)[component_sparse.len]

    ent_ptr :^u32 = ([^]u32)(component_sparse.entity_blob)[dense_id:]
    ent_ptr^ = last_entity

    mask :=  ((dense_id - int(component_sparse.len)) >> 31 & 1)  
    invert_mask := 1 - mask

    last_entity_sparse_val := internal_sparse_get_index(component_sparse, last_entity)
    internal_sparse_put_index(component_sparse, last_entity, (dense_id * invert_mask) | (last_entity_sparse_val * mask))
    internal_sparse_put_index(component_sparse, entity, -1)

    removed_comp_ptr := ([^]component_type)(component_sparse.component_blob)[dense_id:]
    last_comp_ptr := ([^]component_type)(component_sparse.component_blob)[component_sparse.len:]

    removed_component := removed_comp_ptr[0]

    slice.ptr_swap_non_overlapping(removed_comp_ptr,last_comp_ptr, size_of(component_type) )

    return removed_component
}

@(private)
internal_sparse_has :: #force_inline proc(component_sparse : ^ComponentSparse, entity : u32) -> int{
    sparse_val := internal_sparse_get_index(component_sparse,entity)
    return 1 - (sparse_val >> 31) & 1
}

@(private)
internal_sparse_fetch_components :: #force_inline proc(component_sparse : ^ComponentSparse, $component_type : typeid) -> []component_type{
    return ([^]component_type)(component_sparse.component_blob)[:component_sparse.len]
}

@(private)
internal_sparse_fetch_components_upto :: #force_inline proc(component_sparse : ^ComponentSparse, $component_type : typeid, len : int) -> []component_type #no_bounds_check{
    return ([^]component_type)(component_sparse.components)[:len]
}

@(private)
internal_sparse_fetch_entities :: #force_inline proc(component_sparse : ^ComponentSparse) -> []u32 #no_bounds_check{
    return ([^]u32)(component_sparse.entity_blob)[:component_sparse.len]
}

@(private)
internal_sparse_fetch_entities_upto :: #force_inline proc(component_sparse : ^ComponentSparse, len : int) -> []u32 #no_bounds_check{
    return ([^]u32)(component_sparse.entity_blob)[:len]
}

@(private)
internal_sparse_swap :: proc(component_sparse : ^ComponentSparse, dst_entity, src_entity : u32, component_size : int) #no_bounds_check{
    dst_id := internal_sparse_get_index(component_sparse, dst_entity)
    src_id := internal_sparse_get_index(component_sparse, src_entity)

    slice.ptr_swap_non_overlapping(([^]u32)(component_sparse.entity_blob)[dst_id:], ([^]u32)(component_sparse.entity_blob)[src_id:], size_of(u32))
    slice.ptr_swap_non_overlapping(([^]rawptr)(component_sparse.component_blob)[dst_id:], ([^]rawptr)(component_sparse.component_blob)[src_id:], component_size) 
    slice.ptr_swap_non_overlapping(([^]int)(component_sparse.sparse_blob)[dst_entity:], ([^]int)(component_sparse.sparse_blob)[src_entity:], size_of(int))
}

///////////////////////////////////////////////////////////

test :: proc(){

    world := init_world()

 
    //register_as_group(world, int, f64)
    register_as_subgroup(world, ComponentGroup{component_types = {f64, int}}, ComponentGroup{ component_types = {string} })

    entity := create_entity(world)
    entity1 := create_entity(world) // 1
    entity2 := create_entity(world) // 2
    entity3 := create_entity(world) // 3
    entity4 := create_entity(world) // 4

    add_component(world, entity1, 3.3)
    add_component(world, entity, 2.4)
    add_component(world,entity4, 2.1)
    add_component(world, entity3, 2.4)

    add_component(world,entity3, 5)
    add_component(world,entity4, 15)
    add_component(world,entity, 5)

    add_component(world, entity4, "hello")
    add_component(world,entity3, "bob")
    
    remove_component(world,entity4, f64)

    fmt.println(get_entities_with_component(world, int))
    fmt.println(get_entities_with_component(world, f64))
    fmt.println(get_entities_with_component(world, string))

	deinit_world(world)

    fmt.println(size_of(ComponentStore), align_of(ComponentStore))
}

