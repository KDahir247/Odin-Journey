package journey

import "core:slice"
import "core:runtime"
import "core:fmt"
import "core:intrinsics"
import "core:mem"

DEFAULT_ENTITY_STORE_CAPACITY :: 2048
DEFAULT_MAX_ENTITY_WITH_COMPONENT :: 2048



//TODO: khal remove this below
//TODO: khal remove and use distinct _Entity.
//TODO: khal later we will store version and id in a single variable for entity.
@(private)
Entity :: struct{
    id : int, // 8
    version : uint, // 8
}

NULL_ENTITY : u32 : 0b1111_1111_1111_1111_1111_1111_1111_1111

//


////////////////////////////// ECS Utility ////////////////////////////////////

//return 0 for all negative and 1 for all postive and zero.
@(private)
@(optimization_mode="speed")
normalize_value :: #force_inline proc "contextless" (val : int) -> int{
    return (val >> 63) + 1 //arithemtic shift
}

////////////////////////////////////////////////////////////////////////////


/////////////////////////// ECS Query Struct ///////////////////////////////

ECS_Query_Dec :: struct{
    all : []typeid,
    none : []typeid, 
}

///////////////////////////////////////////////////////////////////////////

/////////////////////////// ECS Group ////////////////////////////////////

GroupData :: struct{
    all_query : []typeid,
    start : int,
}


Group :: struct($S : int){
    store_indices : [S]int,
    group_index : int,
}

////////////////////////// ECS World ////////////////////////////////////

ComponentStoreData :: struct{
    group_index : int,
    component_store_index : int,
}

World :: struct{
    entities_stores : EntityStore, 
    components_stores : [dynamic]ComponentStore, 
    component_store_info : map[typeid]ComponentStoreData,
    groups : [dynamic]GroupData,
    //Resource we have to make a way to allow a array of generic type. And only on resource is allowed of the type or a map with key as typid and value as a u8 ptr
    //resource : u32,
}

@(optimization_mode="size")
init_world :: proc() -> ^World{
    world := new(World)
    
    world.entities_stores = init_entity_store(DEFAULT_ENTITY_STORE_CAPACITY)
    world.components_stores = make([dynamic]ComponentStore)
    world.component_store_info = make(map[typeid]ComponentStoreData)
    world.groups = make([dynamic]GroupData)

    return world
}

@(optimization_mode="size")
@(deferred_out=deinit_world)
scope_init_world :: proc() -> ^World{
   return init_world()
}

@(optimization_mode="size")
deinit_world :: proc(world : ^World){
    deinit_entity_store(&world.entities_stores)
    delete(world.components_stores)
    delete(world.component_store_info)
    delete(world.groups)
    free(world)
}


@(optimization_mode="size")
is_register :: #force_inline proc(world : ^World, $component : typeid) -> bool {
    _, valid := world.component_store_info[component]
    return valid
}

@(optimization_mode="size")
register :: proc(world : ^World, $component : typeid){
    if !is_register(world, component){

        world.component_store_info[component] = ComponentStoreData{
            component_store_index = len(world.components_stores),
            group_index = -1,
        }

        append(&world.components_stores, init_component_store(component))

    }
}


// memory allocation function call free all on context.temp_allocator.
@(optimization_mode="size")
all_store_types :: proc(world : ^World) -> []typeid {
    store_types := make_slice([]typeid, len(world.component_store_info), context.temp_allocator)

    current_index := 0

    for store_type in world.component_store_info{
        store_types[current_index] = store_type
        
        current_index += 1
    }

    return store_types
}


@(optimization_mode="speed")
set_component :: proc(world : ^World, entity : Entity, component : $T, $safety_check : bool){
    component_id := world.component_store_info[T].component_store_index
    
    when safety_check{
        if internal_has_component(world.components_stores[component_id], entity) == 1{
            internal_set_component(world.components_stores[component_id], entity, component)
        }
    }else{
        internal_set_component(&world.components_stores[component_id], entity, component)
    }
}


@(optimization_mode="speed")
get_component :: proc(world : ^World, entity : Entity, $component : typeid, $safety_check : bool) -> ^component{
    desired_component : ^component = nil
    
    component_id := world.component_store_info[component].component_store_index

    when safety_check{
        if internal_has_component(world.components_stores[component_id], entity) == 1{
            desired_component = internal_get_component(world.components_stores[component_id], entity, component)
        }
    }else{
        desired_component = internal_get_component(world.components_stores[component_id], entity, component)
    }

    return desired_component
}


@(optimization_mode="speed")
get_entities_with_component :: proc(world : ^World, component : typeid) -> []Entity{
    component_info := world.component_store_info[component]
    return internal_retrieve_entities_with_component(&world.components_stores[component_info.component_store_index])
} 


@(optimization_mode="speed")
get_components_with_id :: proc(world : ^World, $component : typeid) -> []component{
    component_id := world.component_store_info[component].component_store_index
    return internal_retrieve_components(&world.components_stores[component_id],component)
}


@(optimization_mode="speed")
add_component :: proc(world : ^World, entity : Entity, $component : $T){
    component_store_info := world.component_store_info[T]

    internal_insert_component(&world.components_stores[component_store_info.component_store_index], entity, component)

    if component_store_info.group_index != -1{
        group_maybe_add(world, entity, component_store_info.group_index)
    }
}


@(optimization_mode="speed")
remove_component :: proc(world : ^World, entity : Entity, $component_type : typeid, $safety_check : bool){
    component_store_info := world.component_store_info[component_type]

    when safety_check{
        if internal_has_component(&world.components_stores[component_store_info.component_store_index], entity) == 1{
            if component_store_info.group_index != -1{
                group_maybe_remove(world, entity, component_store_info.group_index)
            }
        
            internal_remove_component(&world.components_stores[component_store_info.component_store_index], entity, component_type)
        }

    }else{
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

@(optimization_mode="size")
group :: proc(world : ^World,$size : int,  query_desc : [$E]typeid) -> Group(size) {

    group : Group(len(query_desc))

    group_data : GroupData

    query_descriptor := make_slice([]typeid, len(query_desc))
   
    for index in  0..<len(query_desc){
        query_descriptor[index] = query_desc[index]
    }

    group_data.all_query = query_descriptor

    //TODO: check for recycled group
    append(&world.groups,group_data)

    owned_store := world.component_store_info[query_desc[0]];
    owned_component_store := world.components_stores[owned_store.component_store_index]
    
    group_index := len(world.groups) - 1

    group.group_index = group_index
    for all,index in query_desc{
        store := &world.component_store_info[all];
        store^.group_index = group_index
        group.store_indices[index] = store.component_store_index
    }

    for entity in internal_retrieve_entities_with_component(&owned_component_store){
       group_maybe_add(world, entity, group_index)
    }


    return group
}

@(optimization_mode="speed")
fetch_group_entities :: proc(world : ^World, group : Group($S)) -> []Entity{
    return internal_retrieve_entities_with_component_upto(&world.components_stores[group.store_indices[0]], world.groups[group.group_index].start)
}

@(optimization_mode="speed")
fetch_group_element_at :: proc(world : ^World, group : Group($S), $index : int, $type : typeid) -> []type{
    assert(world.components_stores[group.store_indices[index]].type == type, "Element order is incorrect when fetching group element")

    return internal_retrieve_components_upto(&world.components_stores[group.store_indices[index]], type, world.groups[group.group_index].start)
}

@(private)
@(optimization_mode="speed")
group_maybe_add :: proc(world : ^World, entity : Entity, group_index : int){
    store_group := &world.groups[group_index]

    is_valid := 1

    for all in store_group.all_query{
        store := world.component_store_info[all];
        component_store := world.components_stores[store.component_store_index]
        is_valid &= internal_has_component(&world.components_stores[store.component_store_index], entity)
    }

    offset_index := (1.0 - is_valid) * len(store_group.all_query)

    for all in store_group.all_query[offset_index:]{
        store := &world.component_store_info[all];
        component_store := &world.components_stores[store.component_store_index]

        if (component_store.sparse[entity.id] > store_group.start) do internal_swap_value(component_store, internal_get_entity(component_store, store_group.start), entity)
    }

    store_group.start += is_valid
}

@(private)
@(optimization_mode="speed")
group_maybe_remove :: proc(world : ^World, entity : Entity, group_index : int){
    store_group := &world.groups[group_index]
    all_components := store_group.all_query

    is_valid := 1
    swap_index := store_group.start - 1

    for all in all_components{
        store := world.component_store_info[all];
        component_store := world.components_stores[store.component_store_index]

        is_valid &= internal_has_component(&component_store, entity)
    }

    offset_mask := 1 - (is_valid & normalize_value(swap_index)); //swap_index > 0
    offset_index := len(all_components) * offset_mask

    for all in all_components[offset_index:]{
        store := world.component_store_info[all];
        component_store := world.components_stores[store.component_store_index]

        internal_swap_value(&component_store, internal_get_entity(&component_store, swap_index), entity)
    }
        
    store_group.start -= is_valid

}

// Slower way to query over sparse set to get multiple components and entity
// Not restrictive as group, since there is no dependencies.

//TODO: khal not done.
@(optimization_mode="speed")
query :: proc(world : ^World,  query_desc : ECS_Query_Dec){

    first_must := query_desc.all[0]
    group_index := world.component_store_info[first_must].group_index

}

@(optimization_mode="speed")
create_entity :: proc(world : ^World) -> u32{
    return internal_create_entity(&world.entities_stores)
}

//TODO: khal not done.
// Relatively slow... currently, since we don't know the component the entity actually has (we need to do linear lookup)
// Got to structure this differently so it doesn't have to do a linear search.
@(optimization_mode="speed")
remove_entity :: proc(world : ^World, entity : Entity){

    for type, component_data in world.component_store_info{

        component_store := &world.components_stores[component_data.component_store_index]

        if internal_has_component(component_store, entity) == 1{

            if component_data.group_index != -1{

                // It is register in a group we need to conform to the order of the group.
                // so we need to get the entity pos that we want to delete in the packed array
                // then swap it with the last valid entity in the group then decrement the group end by 1
                // then we can remove it since removing it will swap the component and entity in the packed array with the last
                // and this might not be added in the group, since it doesn't satisfy the query_desc in the group.
            }

            //TODO: khal removed_component need a constant typeid..
            //internal_remove_component(component_store, entity, type)
        }
    }

    //TODO: khal we want to remove the group if the entity is in a group
    //TODO: we want to remove the component it has in the component store.
    //then we can call destroy entity 
    //internal_destroy_entity(&world.entities_stores, entity)
}

///////////////////////////////////////////////////////////////////

//////////////////////// Entity Store /////////////////////////////

EntityStore :: struct{
    entities : [dynamic]u32,
    available_to_recycle : int,
    next_recycle : u32,
}

@(private)
@(optimization_mode="size")
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
@(optimization_mode="size")
deinit_entity_store :: proc(entity_store : ^EntityStore){
    delete_dynamic_array(entity_store.entities)
}
@(private)
@(optimization_mode="size")
internal_create_entity :: proc(entity_store : ^EntityStore) -> u32{
    entity : u32 

   if entity_store.available_to_recycle > 0{
    entity = entity_store.next_recycle 

    entity_store.next_recycle = u32(entity_store.entities[entity] >> 16)
    entity_store.entities[entity] = (entity + 1)  << 16

    entity_store.available_to_recycle -= 1
   }else{
    entity = u32(len(entity_store.entities))

    append(&entity_store.entities, (entity + 1) << 16)
   }

   return entity
}

@(private)
@(optimization_mode="size")
internal_destroy_entity :: proc(entity_store : ^EntityStore, entity : u32) #no_bounds_check{
    version_bit := entity_store.entities[entity] & 0xFFFF
    entity_store.entities[entity] = (entity_store.next_recycle << 16) + (version_bit + 1)
    entity_store.available_to_recycle += 1

    entity_store.next_recycle = entity 
}


@(private)
@(optimization_mode="speed")
internal_entity_is_valid :: #force_inline proc(entity_store : ^EntityStore, entity : u32) -> int{
    return u32(len(entity_store.entities) -1) > entity ? 1 : 0
}

@(private)
@(optimization_mode="speed")
internal_entity_is_alive :: #force_inline proc(entity_store : ^EntityStore, entity : u32) -> int #no_bounds_check{
    entity_val := entity + 1
    return entity_val == entity_store.entities[entity] >> 16 ? 1 : 0
}


//////////////////////////////////////////////////////////////////

///////////////////// Component Store ///////////////////////////

ComponentStore :: struct #align 64 { // 40
    sparse : []int, 
    entities : rawptr,
    components : rawptr, 
    len : int,  
    type : typeid,
}


@(private)
@(optimization_mode="size")
deinit_component_store :: proc(comp_storage : ComponentStore){
    delete_slice(comp_storage.sparse)
    free(comp_storage.components)
    free(comp_storage.entities)
}

@(private)
@(optimization_mode="size")
init_component_store :: proc(type : typeid, size := DEFAULT_MAX_ENTITY_WITH_COMPONENT) -> ComponentStore{
    raw_components,_ := mem.alloc(size_of(type) * size, 64)
    raw_entities,_ := mem.alloc(size_of(Entity) * size, 64)
    sparse := make_slice([]int, size)

    //len(sparse) << 3 is a faster of sizeof(int) * len(sparse) where sizeof(int) == 8 
    runtime.memset(&sparse[0], -1,size << 3)

    return ComponentStore{
        sparse = sparse,
        entities = raw_entities,
        components = raw_components,
        len = 0,
        type = type,
    }
}

@(private)
@(optimization_mode="size")
internal_insert_component :: proc(component_storage : ^ComponentStore, entity : Entity, component : $T) #no_bounds_check{
    local_component := component
    local_entity := entity

    dense_id := component_storage.sparse[entity.id]
    has_mask := internal_has_component(component_storage, entity)
    incr_mask := (1.0 -  has_mask)

    dense_index := (component_storage.len * incr_mask) + (dense_id * has_mask)

    component_storage.sparse[entity.id] = dense_index

    comp_ptr :^T= ([^]T)(component_storage.components)[dense_index:]
    ent_ptr :^Entity= ([^]Entity)(component_storage.entities)[dense_index:]
    
    comp_ptr^ = local_component
    ent_ptr^ = local_entity

    component_storage.len += incr_mask
}

@(private)
@(optimization_mode="speed")
internal_get_component :: proc(component_storage : ^ComponentStore, entity : Entity, $component : typeid) -> ^component  #no_bounds_check{
    dense_index := component_storage.sparse[entity.id]
    return &([^]component)(component_storage.components)[dense_index]
}

@(private)
@(optimization_mode="speed")
internal_get_entity :: #force_inline proc(component_storage : ^ComponentStore, index : int) -> Entity {
    return internal_retrieve_entities_with_component(component_storage)[index]
}


@(private)
@(optimization_mode="speed")
internal_set_component :: proc(component_storage : ^ComponentStore, entity : Entity, component : $T) #no_bounds_check {
    dense_id := component_storage.sparse[entity.id]
    comp_ptr :^T= ([^]T)(component_storage.components)[dense_id:] 
    comp_ptr^ = component
}

@(private)
@(optimization_mode="size")
internal_remove_component :: proc(component_storage : ^ComponentStore, entity : Entity, $component : typeid) -> component{

    //TODO: should i put the removed entity in the last element then decrement the len by one. So if we insert the same thing we removed then it is technically cached.. 
    // And should i also put the removed component in the last element then decrement the len by one, So it is is a sense cached.
    dense_id := component_storage.sparse[entity.id]
        
    component_storage.len -= 1

    last_entity := ([^]Entity)(component_storage.entities)[component_storage.len]

    ent_ptr :^Entity = ([^]Entity)(component_storage.entities)[dense_id:]
    ent_ptr^ = last_entity

    mask :=  ((dense_id - component_storage.len) >> 31 & 1)  
    invert_mask := 1 - mask

    component_storage.sparse[last_entity.id] = (dense_id * invert_mask) | (component_storage.sparse[last_entity.id] * mask)  
    component_storage.sparse[entity.id] = -1
    
    removed_comp_ptr := ([^]component)(component_storage.components)[dense_id:]
    last_comp_ptr := ([^]component)(component_storage.components)[component_storage.len:]

    removed_component := removed_comp_ptr[0]

    slice.ptr_swap_non_overlapping(removed_comp_ptr,last_comp_ptr, size_of(component_storage.type) )

    return removed_component
}

@(private)
@(optimization_mode="speed")
internal_has_component :: #force_inline proc(component_storage : ^ComponentStore, entity : Entity) -> int #no_bounds_check{
    return 1 - (component_storage.sparse[entity.id] >> 31) & 1
}


@(private)
@(optimization_mode="speed")
internal_retrieve_components :: #force_inline proc(component_storage : ^ComponentStore, $component_type : typeid) -> []component_type #no_bounds_check{
    return ([^]component_type)(component_storage.components)[:component_storage.len]
}

@(private)
@(optimization_mode="speed")
internal_retrieve_components_upto :: #force_inline proc(component_storage : ^ComponentStore, $component_type : typeid, len : int) -> []component_type #no_bounds_check{
    return ([^]component_type)(component_storage.components)[:len]
}

@(private)
@(optimization_mode="speed")
internal_retrieve_entities_with_component :: #force_inline proc(component_storage : ^ComponentStore) -> []Entity #no_bounds_check{
    return ([^]Entity)(component_storage.entities)[:component_storage.len]
}

@(private)
@(optimization_mode="speed")
internal_retrieve_entities_with_component_upto :: #force_inline proc(component_storage : ^ComponentStore, len : int) -> []Entity #no_bounds_check{
    return ([^]Entity)(component_storage.entities)[:len]
}

@(private)
@(optimization_mode="speed")
internal_swap_value :: proc(component_storage : ^ComponentStore, dst_entity, src_entity : Entity) #no_bounds_check{
    dst_id := component_storage.sparse[dst_entity.id]
    src_id := component_storage.sparse[src_entity.id]

    slice.ptr_swap_non_overlapping(([^]Entity)(component_storage.entities)[dst_id:], ([^]Entity)(component_storage.entities)[src_id:], size_of(Entity))
    slice.ptr_swap_non_overlapping(([^]rawptr)(component_storage.components)[dst_id:], ([^]rawptr)(component_storage.components)[src_id:], size_of(component_storage.type))
    slice.swap(component_storage.sparse, dst_entity.id, src_entity.id)
}

///////////////////////////////////////////////////////////

test :: proc(){
    entity : Entity = {0, 2}
    entity1 : Entity = {1, 2}
    entity2 : Entity = {2, 2}

    entity3 :Entity = {10 , 4}
    entity4 :Entity = {20 , 4}

    world := init_world()

    f := ECS_Query_Dec{
        all = []typeid{ },
    }

    register(world, f64)
    register(world, int)

    //group(world, f)

    add_component(world,entity4, 5)
    add_component(world,entity, 5)
    add_component(world,entity2, 10)
    add_component(world,entity, 30)


    group := group(world,2, [2]typeid{f64, int})

    add_component(world, entity1, 3.3)
    add_component(world, entity2, 2.0)
    add_component(world,entity3, 1.14)
    add_component(world, entity, 5.5)
    add_component(world,entity4, 2.1)
    
   

    remove_component(world, entity2, f64, true)


    entities := fetch_group_entities(world, group)
    float  := fetch_group_element_at(world, group, 0, f64)
    integer := fetch_group_element_at(world, group, 1, int)

    for i in 0..<len(entities){
        fmt.println(integer[i])
        integer[i] += 10
        fmt.println(integer[i])
    }

    // v: =  NULL_ENTITY & 0x80000000

    // fmt.println(i32(NULL_ENTITY & 0x7FFFFFFF) - i32(v))
    

    // a := []f32{2.0, 3.0, 4.0, 5.0}

    // for b in a[:0]{
    //     fmt.println("call",b)
    // }

    ///////////////////////// Entity Store test //////////////////////////////////


    // entity_store : EntityStore = init_entity_store(2048)

    // a := internal_create_entity(&entity_store)
    // b := internal_create_entity(&entity_store)
    // c := internal_create_entity(&entity_store)
    // d := internal_create_entity(&entity_store)
    // e := internal_create_entity(&entity_store)
    // f := internal_create_entity(&entity_store)
    // g := internal_create_entity(&entity_store)

    //  internal_destroy_entity(&entity_store, a)
    //  fmt.println(internal_entity_is_alive(&entity_store, a))
    //  internal_destroy_entity(&entity_store, d)
    //  fmt.println(internal_entity_is_alive(&entity_store, a))

    //  internal_destroy_entity(&entity_store, g)
    //  fmt.println(entity_store)

    //  internal_create_entity(&entity_store)
    //  internal_create_entity(&entity_store)
    //  internal_create_entity(&entity_store)
    //  fmt.println(internal_entity_is_alive(&entity_store, a))

    // fmt.println(entity_store)
    

}
