package journey

import "core:slice"
import "core:runtime"
import "core:fmt"
import "core:intrinsics"
import "core:mem"

// u16 maximum value, since currently we split a u32 in half hi u16 is id lo u16 is version
DEFAULT_MAX_ENTITY :: 65535

////////////////////////////// ECS Utility ////////////////////////////////////

//return 0 for all negative and 1 for all postive and zero.
@(private)
normalize_value :: #force_inline proc "contextless" (val : int) -> int{
    return (val >> 63) + 1 //arithemtic shift
}

////////////////////////////////////////////////////////////////////////////


/////////////////////////// ECS Group ////////////////////////////////////

GroupData :: struct{
    store_indices : []int,
    start : int,
}

////////////////////////// ECS World ////////////////////////////////////

ComponentStoreData :: struct{
    group_index : int,
    component_store_index : int,
}

World :: struct{
    entities_stores : EntityStore,
    component_store_info : map[typeid]ComponentStoreData,
    components_stores : [dynamic]ComponentStore, 
    groups : [dynamic]GroupData,
}

init_world :: proc() -> ^World{
    world := new(World)
    
    world.entities_stores = init_entity_store(DEFAULT_MAX_ENTITY)
    world.components_stores = make([dynamic]ComponentStore)
    world.component_store_info = make(map[typeid]ComponentStoreData)
    world.groups = make([dynamic]GroupData)

    return world
}

@(deferred_out=deinit_world)
scope_init_world :: proc() -> ^World{
   return init_world()
}

deinit_world :: proc(world : ^World){
    deinit_entity_store(&world.entities_stores)

    for store in world.components_stores{
        deinit_component_store(store)
    }

    delete(world.components_stores)
    delete(world.component_store_info)

    for group in world.groups{
        delete(group.store_indices)
    }

    delete(world.groups)
}

is_register :: #force_inline proc(world : ^World, $component : typeid) -> bool {
    _, valid := world.component_store_info[component]
    return valid
}

register :: proc(world : ^World, $component : typeid, max_component := DEFAULT_MAX_ENTITY){
    if !is_register(world, component){

        world.component_store_info[component] = ComponentStoreData{
            component_store_index = len(world.components_stores),
            group_index = -1,
        }

        append(&world.components_stores, init_component_store(component, max_component))
    }
}

set_component :: proc(world : ^World, entity : u32, component : $T){

    if intrinsics.expect(internal_entity_is_alive(&world.entities_stores, entity), true){
        component_id := world.component_store_info[T].component_store_index
        internal_set_component(&world.components_stores[component_id], entity, component)
    }
}

get_component :: proc(world : ^World, entity : u32, $component : typeid) -> ^component{
    desired_component : ^component = nil

    if intrinsics.expect(internal_entity_is_alive(&world.entities_stores, entity), true){
        component_id := world.component_store_info[component].component_store_index

        desired_component = internal_get_component(&world.components_stores[component_id], entity, component)    
    }

    return desired_component
}

get_entities_with_component :: proc(world : ^World, component : typeid) -> []u32{
    component_info := world.component_store_info[component]
    return internal_retrieve_entities_with_component(&world.components_stores[component_info.component_store_index])
} 

get_components_with_id :: proc(world : ^World, $component : typeid) -> []component{
    component_id := world.component_store_info[component].component_store_index
    return internal_retrieve_components(&world.components_stores[component_id],component)
}


add_component :: proc(world : ^World, entity : u32, component : $T){
    if intrinsics.expect(internal_entity_is_alive(&world.entities_stores, entity), true){

        component_store_info := world.component_store_info[T]

        internal_insert_component(&world.components_stores[component_store_info.component_store_index], entity, component)
    
        if component_store_info.group_index != -1{
            group_maybe_add(world, entity, component_store_info.group_index)
        }
    }
}

remove_component :: proc(world : ^World, entity : u32, $component_type : typeid){

    if intrinsics.expect(internal_entity_is_alive(&world.entities_stores, entity), true){
        component_store_info := world.component_store_info[component_type]

        if component_store_info.group_index != -1{
            group_maybe_remove(world, entity, component_store_info.group_index)
        }
    
        internal_remove_component(&world.components_stores[component_store_info.component_store_index], entity, component_type)
    }
}

// Really fast way to query over the sparse set to get multiple components and entity
// But it is restrictive it order the component sparse with using similar entity in other component that is 
// in the same group. Also we want have a component in mutliple group, so Position in group 1 can't also be added to group two
// unless the position is removed from group 1 
// Checking if component is part of another group is not checked and handled it will cause undefined behaviour currently.

group :: proc(world : ^World,   query_desc : ..typeid) -> int {
    group_data : GroupData

    store_indices := make_slice([]int, len(query_desc))
   
    for index in  0..<len(query_desc){
        query_type := query_desc[index]
        store_indices[index] = world.component_store_info[query_type].component_store_index
    }

    group_data.store_indices = store_indices

    //TODO: check for recycled group
    append(&world.groups,group_data)

    owned_store := world.component_store_info[query_desc[0]]
    owned_component_store := world.components_stores[owned_store.component_store_index]
    
    group_index := len(world.groups) - 1

    for all,index in query_desc{
        store := &world.component_store_info[all];
        store^.group_index = group_index
    }

    for entity in internal_retrieve_entities_with_component(&owned_component_store){
       group_maybe_add(world, entity, group_index)
    }

    return group_index
}

fetch_group_entities :: proc(world : ^World, group_index : int) -> []u32{
    group := world.groups[group_index]

    return internal_retrieve_entities_with_component_upto(&world.components_stores[group.store_indices[0]], group.start)
}

fetch_group_element_at :: proc(world : ^World, group_index : int, $index : int, $type : typeid) -> []type{
    group := world.groups[group_index]

    assert(world.components_stores[group.store_indices[index]].type == type, "Element order is incorrect when fetching group element")

    return internal_retrieve_components_upto(&world.components_stores[group.store_indices[index]], type, group.start)
}

@(private)
group_maybe_add :: proc(world : ^World, entity : u32, group_index : int){

    store_group := &world.groups[group_index]

    is_valid := 1

    for store_index in store_group.store_indices{
        is_valid &= internal_has_component(&world.components_stores[store_index], entity)
    }


    offset_index := (1.0 - is_valid) * len(store_group.store_indices)

    for store_index in store_group.store_indices[offset_index:]{

        component_store := &world.components_stores[store_index]

        if (component_store.sparse[entity] > store_group.start) do internal_swap_value(component_store, internal_get_entity(component_store, store_group.start), entity)

    }

    store_group.start += is_valid
}

@(private)
group_maybe_remove :: proc(world : ^World, entity : u32, group_index : int){

    store_group := &world.groups[group_index]

    is_valid := 1
    swap_index := store_group.start - 1

    for store_index in store_group.store_indices{
        is_valid &= internal_has_component(&world.components_stores[store_index], entity)
    }

    offset_mask := 1 - (is_valid & normalize_value(swap_index)); //swap_index > 0
    offset_index := len(store_group.store_indices) * offset_mask

    for store_index in store_group.store_indices[offset_index:]{
        component_store := &world.components_stores[store_index]

        internal_swap_value(component_store, internal_get_entity(component_store, swap_index), entity)
    }
        
    store_group.start -= is_valid
}

// Slower way to query over sparse set to get multiple components and entity
// Not restrictive as group, since there is no dependencies.

//TODO: khal not done.
query :: proc(world : ^World,  query_desc : ..typeid){

    first_must := query_desc[0]
    group_index := world.component_store_info[first_must].group_index

}

create_entity :: proc(world : ^World) -> u32{
    return internal_create_entity(&world.entities_stores)
}

//TODO: khal not done.
// Relatively slow... currently, since we don't know the component the entity actually has (we need to do linear lookup)
// Got to structure this differently so it doesn't have to do a linear search.
// remove_entity :: proc(world : ^World, entity : u32){

//     for type, component_data in world.component_store_info{

//         component_store := &world.components_stores[component_data.component_store_index]

//         if internal_has_component(component_store, entity) == 1{

//             if component_data.group_index != -1{

//                 // It is register in a group we need to conform to the order of the group.
//                 // so we need to get the entity pos that we want to delete in the packed array
//                 // then swap it with the last valid entity in the group then decrement the group end by 1
//                 // then we can remove it since removing it will swap the component and entity in the packed array with the last
//                 // and this might not be added in the group, since it doesn't satisfy the query_desc in the group.
//             }

//             //TODO: khal removed_component need a constant typeid..
//             //internal_remove_component(component_store, entity, type)
//         }
//     }

//     //TODO: khal we want to remove the group if the entity is in a group
//     //TODO: we want to remove the component it has in the component store.
//     //then we can call destroy entity 
//     //internal_destroy_entity(&world.entities_stores, entity)
// }

///////////////////////////////////////////////////////////////////

//////////////////////// Entity Store /////////////////////////////

EntityStore :: struct{
    entities : [dynamic]u32,
    available_to_recycle : int,
    next_recycle : u32,
}

@(private)
init_entity_store :: proc($capacity : int) -> EntityStore{
    entities := make([dynamic]u32, 0,capacity)
    
    entity_store := EntityStore{
        entities = entities,
        available_to_recycle = 0,
        next_recycle = 0,
    }
    
    return entity_store
}

@(private)
deinit_entity_store :: proc(entity_store : ^EntityStore){
    delete_dynamic_array(entity_store.entities)
}
@(private)
internal_create_entity :: proc(entity_store : ^EntityStore) -> u32{
    entity : u32 

   if entity_store.available_to_recycle > 0{
    entity = entity_store.next_recycle 

    entity_store.next_recycle = entity_store.entities[entity] >> 16
    entity_store.entities[entity] = (entity + 1)  << 16

    entity_store.available_to_recycle -= 1
   }else{
    entity = u32(len(entity_store.entities))

    append(&entity_store.entities, (entity + 1) << 16)
   }

   return entity
}

@(private)
internal_destroy_entity :: proc(entity_store : ^EntityStore, entity : u32) #no_bounds_check{
    version_bit := entity_store.entities[entity] & 0xFFFF
    entity_store.entities[entity] = (entity_store.next_recycle << 16) + (version_bit + 1)
    entity_store.available_to_recycle += 1

    entity_store.next_recycle = entity 
}


@(private)
internal_entity_is_valid :: #force_inline proc(entity_store : ^EntityStore, entity : u32) -> int{
    return u32(len(entity_store.entities) -1) > entity ? 1 : 0
}

@(private)
internal_entity_is_alive :: #force_inline proc(entity_store : ^EntityStore, entity : u32) -> bool #no_bounds_check{
    entity_val := entity + 1
    return entity_val == (entity_store.entities[entity] >> 16)
}


//////////////////////////////////////////////////////////////////

///////////////////// Component Store ///////////////////////////

ComponentStore :: struct #align 64 { // 40
    entities : rawptr,
    components : rawptr, 
    sparse : []int, 

    len : int,  
    type : typeid,
}


@(private)
deinit_component_store :: proc(comp_storage : ComponentStore){
    delete_slice(comp_storage.sparse)
    free(comp_storage.components)
    free(comp_storage.entities)
}

@(private)
init_component_store :: proc(type : typeid, maximum_component : int) -> ComponentStore{
    raw_components,_ := mem.alloc(size_of(type) * maximum_component)
    raw_entities,_ := mem.alloc(maximum_component << 2)
    sparse := make_slice([]int, DEFAULT_MAX_ENTITY)

    runtime.memset(&sparse[0], -1, DEFAULT_MAX_ENTITY << 3)

    return ComponentStore{
        sparse = sparse,
        entities = raw_entities,
        components = raw_components,
        len = 0,
        type = type,
    }
}

@(private)
internal_insert_component :: proc(component_storage : ^ComponentStore, entity : u32, component : $T) #no_bounds_check{
    local_component := component
    local_entity := entity

    dense_id := component_storage.sparse[entity]
    has_mask := internal_has_component(component_storage, entity)
    incr_mask := (1.0 -  has_mask)

    dense_index := (component_storage.len * incr_mask) + (dense_id * has_mask)

    component_storage.sparse[entity] = dense_index

    comp_ptr :^T= ([^]T)(component_storage.components)[dense_index:]
    ent_ptr :^u32= ([^]u32)(component_storage.entities)[dense_index:]
    
    comp_ptr^ = local_component
    ent_ptr^ = local_entity

    component_storage.len += incr_mask
}


@(private)
internal_get_component :: proc(component_storage : ^ComponentStore, entity : u32, $component : typeid) -> ^component {
    dense_index := component_storage.sparse[entity]
    return &([^]component)(component_storage.components)[dense_index]
}

@(private)
internal_get_entity :: #force_inline proc(component_storage : ^ComponentStore, index : int) -> u32 {
    return internal_retrieve_entities_with_component(component_storage)[index]
}


@(private)
internal_set_component :: proc(component_storage : ^ComponentStore, entity : u32, component : $T) {
    dense_id := component_storage.sparse[entity.id]
    comp_ptr :^T= ([^]T)(component_storage.components)[dense_id:] 
    comp_ptr^ = component
}

@(private)
internal_remove_component :: proc(component_storage : ^ComponentStore, entity : u32, $component : typeid) -> component{

    //TODO: should i put the removed entity in the last element then decrement the len by one. So if we insert the same thing we removed then it is technically cached.. 
    // And should i also put the removed component in the last element then decrement the len by one, So it is is a sense cached.
    dense_id := component_storage.sparse[entity]
        
    component_storage.len -= 1

    last_entity := ([^]u32)(component_storage.entities)[component_storage.len]

    ent_ptr :^u32 = ([^]u32)(component_storage.entities)[dense_id:]
    ent_ptr^ = last_entity

    mask :=  ((dense_id - component_storage.len) >> 31 & 1)  
    invert_mask := 1 - mask

    component_storage.sparse[last_entity] = (dense_id * invert_mask) | (component_storage.sparse[last_entity] * mask)  
    component_storage.sparse[entity] = -1
    
    removed_comp_ptr := ([^]component)(component_storage.components)[dense_id:]
    last_comp_ptr := ([^]component)(component_storage.components)[component_storage.len:]

    removed_component := removed_comp_ptr[0]

    slice.ptr_swap_non_overlapping(removed_comp_ptr,last_comp_ptr, size_of(component_storage.type) )

    return removed_component
}

@(private)
internal_has_component :: #force_inline proc(component_storage : ^ComponentStore, entity : u32) -> int{
    return 1 - (component_storage.sparse[entity] >> 31) & 1
}


@(private)
internal_retrieve_components :: #force_inline proc(component_storage : ^ComponentStore, $component_type : typeid) -> []component_type{
    return ([^]component_type)(component_storage.components)[:component_storage.len]
}

@(private)
internal_retrieve_components_upto :: #force_inline proc(component_storage : ^ComponentStore, $component_type : typeid, len : int) -> []component_type #no_bounds_check{
    return ([^]component_type)(component_storage.components)[:len]
}

@(private)
internal_retrieve_entities_with_component :: #force_inline proc(component_storage : ^ComponentStore) -> []u32 #no_bounds_check{
    return ([^]u32)(component_storage.entities)[:component_storage.len]
}

@(private)
internal_retrieve_entities_with_component_upto :: #force_inline proc(component_storage : ^ComponentStore, len : int) -> []u32 #no_bounds_check{
    return ([^]u32)(component_storage.entities)[:len]
}

@(private)
internal_swap_value :: proc(component_storage : ^ComponentStore, dst_entity, src_entity : u32) #no_bounds_check{
    dst_id := component_storage.sparse[dst_entity]
    src_id := component_storage.sparse[src_entity]

    slice.ptr_swap_non_overlapping(([^]u32)(component_storage.entities)[dst_id:], ([^]u32)(component_storage.entities)[src_id:], 4)
    slice.ptr_swap_non_overlapping(([^]rawptr)(component_storage.components)[dst_id:], ([^]rawptr)(component_storage.components)[src_id:], size_of(component_storage.type))

    slice.swap(component_storage.sparse, int(dst_entity), int(src_entity))
}
///////////////////////////////////////////////////////////

test :: proc(){

    world := init_world()

    
    register(world, f64)
    register(world, int)

    entity := create_entity(world)
    entity1 := create_entity(world) // 1
    entity2 := create_entity(world) // 2
    entity3 := create_entity(world) // 3
    entity4 := create_entity(world) // 4
    
    group := group(world, f64, int)

    add_component(world,entity, 5)
    add_component(world,entity2, 10)
    add_component(world,entity, 30)


    add_component(world, entity1, 3.3)
    add_component(world, entity2, 2.0)
    add_component(world,entity3, 1.14)
    add_component(world, entity, 5.5)
    add_component(world,entity4, 2.1)

}
