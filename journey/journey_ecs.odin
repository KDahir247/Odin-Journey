package journey

import "core:slice"
import "core:runtime"
import "core:fmt"
import "core:intrinsics"
import "core:mem"


Test_Struct :: struct{
    b : int,
}

DEFAULT_MAX_ENTITY_WITH_COMPONENT :: 2048
INVALID_ENTITY :: Entity{-1, 0}

//16
@(private)
Entity :: struct{
    id : int, // 8
    version : uint, // 8
}

////////////////////////////// ECS Utility ////////////////////////////////////
//size must have all bit set to one plus 1. eg. 0b0111 == 7 then we add 1 so 8
@(private)
Small_Circular_Buffer :: struct($size : uint){
    buffer : []Entity, // 16 byte
    // HI 32 bit are the tail the LO 32 bit are the head
    shared_index : uint, // 8
}

@(optimization_mode="size")
init_circular_buffer :: proc(q : ^$Q/Small_Circular_Buffer($T)){
    q^.buffer = make_slice([]Entity, T)
    q.shared_index = 0
}

@(optimization_mode="size")
deinit_circular_buffer :: proc(q : ^$Q/Small_Circular_Buffer($T)){
    delete_slice(q^.buffer)
    q.shared_index = 0
}

//TODO: khal break dependencies.

@(optimization_mode="speed")
enqueue :: proc(q : ^$Q/Small_Circular_Buffer($T), entity : Entity){
    head := q.shared_index >> 32

    q.buffer[head] = entity

    next_head := (head + 1) & (T - 1)
    q.shared_index = (next_head << 32) | (q.shared_index & 0xFFFFFFFF)
}

@(optimization_mode="speed")
dequeue :: proc(q : ^$Q/Small_Circular_Buffer($T)) -> Entity{
    tail := (q.shared_index & 0xFFFFFFFF)

    value := q.buffer[tail]

    next_tail := (tail + 1) & (T - 1)
    q.shared_index = (q.shared_index & 0xFFFFFFFF00000000) | next_tail
    
    return value
}

@(optimization_mode="size")
clear :: proc(q : ^$Q/Small_Circular_Buffer($T)){
    q.shared_index = 0
    intrinsics.mem_zero(raw_data(q.buffer), size_of(Entity) * len(q.buffer))
}


@(optimization_mode="speed")
contains :: proc(q : ^$Q/Small_Circular_Buffer($T)) -> bool{
    return (q.shared_index >> 32) > (q.shared_index & 0xFFFFFFFF)
}
////////////////////////////////////////////////////////////////////////////


/////////////////////////// ECS Query Struct ///////////////////////////////


ECS_Query_Dec :: struct #align 64{
    all : []typeid,
    //some : []typeid,
    none : []typeid, 
}

///////////////////////////////////////////////////////////////////////////

/////////////////////////// ECS Group ////////////////////////////////////

GroupData :: struct{
    start : int,
    new_target : int,
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
    
    world.entities_stores = init_entity_store()
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


@(optimization_mode="speed")
is_register :: #force_inline proc(world : ^World, $component : typeid) -> bool {
    _, valid := world.component_store_info[component]
    return valid
}

@(optimization_mode="speed")
register :: proc(world : ^World, $component : typeid){
    if !is_register(world, component){

        world.component_store_info[component] = ComponentStoreData{
            component_store_index = len(world.components_stores),
            group_index = -1,
        }

        append(&world.components_stores, init_component_store(component))

    }
}



@(deferred_out=delete_type_slice)
@(optimization_mode="speed")
all_store_types :: proc(world : ^World) -> []typeid {
    store_types := make_slice([]typeid, len(world.component_store_info))

    current_index := 0

    for store_type in world.component_store_info{
        store_types[current_index] = store_type
        
        current_index += 1
    }

    return store_types
}

@(private)
@(optimization_mode="speed")
delete_type_slice :: proc(store_types : []typeid){
    delete(store_types)
}


@(optimization_mode="speed")
set_component :: proc(world : ^World, entity : Entity, component : $T, $safety_check : bool){
    component_id := world.component_store_info[component].component_store_index

    // constant bool if statement will almost always get optimized out by compiler.
    // we indicate we want optimize for speed as well, so this if statement should be optimized out to just one path
    if safety_check{
        if internal_has_component(world.components_stores[component_id], entity) == 1{
            internal_set_component(world.components_stores[component_id], entity, component)
        }
    }else{
        internal_set_component(world.components_stores[component_id], entity, component)
    }
}


@(optimization_mode="speed")
get_component :: proc(world : ^World, entity : Entity, $component : typeid, $safety_check : bool) -> ^component{
    
    component_id := world.component_store_info[component].component_store_index

    desired_component : ^component = nil

    // constant bool if statement will almost always get optimized out by compiler.
    // we indicate we want optimize for speed as well, so this if statement should be optimized out to just one path
    if safety_check{
        if internal_has_component(world.components_stores[component_id], entity) == 1{
            desired_component = internal_get_component(world.components_stores[component_id], entity, component)
        }
    }else{
        desired_component = internal_get_component(world.components_stores[component_id], entity, component)
    }

    return desired_component
}


@(optimization_mode="speed")
get_entities_with_component :: proc(world : ^World, $component : typeid) -> []Entity{
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
    target_component_store := world.component_store_info[T]

    //It is part of a group if it is not -1 then we need a specific add component to the component store to sort 
    if target_component_store.group_index != -1{

    }else{
    internal_insert_component(&world.components_stores[target_component_store.component_store_index], entity, component)
    }
}

// Really fast way to query over the sparse set to get multiple components and entity
// But it is restrictive it order the component sparse with using similar entity in other component that is 
// in the same group. Also we want have a component in mutliple group, so Position in group 1 can't also be added to group two
// unless the position is removed from group 1 
// Checking if component is part of another group is not checked and handled it will cause undefined behaviour currently.

//TODO: khal not done.
@(optimization_mode="size")
group :: proc(world : ^World,  query_desc : ECS_Query_Dec) {
    group_data : GroupData
    is_valid : bool = true

    //TODO: check for recycled group

    append(&world.groups,group_data)

    group_index := len(world.groups) - 1

    owned_store := world.component_store_info[query_desc.all[0]];
    owned_component_store := world.components_stores[owned_store.component_store_index]

    for all in query_desc.all{
        store := &world.component_store_info[all];
        store^.group_index = group_index
    }


    current := 0
    
    for entity, index in internal_retrieve_entities_with_component(&owned_component_store){


        is_valid = true

        //See if it has all the components in the query.
        for all in query_desc.all{
            store := &world.component_store_info[all];
            component_store := world.components_stores[store.component_store_index]
            is_valid &= bool(internal_has_component(&world.components_stores[store.component_store_index], entity))
        }


        if is_valid {

            for all in query_desc.all{
                store := &world.component_store_info[all];
                component_store := &world.components_stores[store.component_store_index]


                fmt.println(all, current)
             
            
                //Swap the entity with current

            }


            //After we updated all increment current.
            //TODO: khal current will be replaced with the group start.. 

            current += 1

        }
       
    }
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
create_entity :: proc(world : ^World) -> Entity{
    return internal_create_entity(&world.entities_stores)
}

//TODO: khal not done.

// Relatively slow... currently, since we don't know the component the entity actually has (we need to do linear lookup)
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
    internal_destroy_entity(&world.entities_stores, entity)
}

///////////////////////////////////////////////////////////////////

//////////////////////// Entity Store /////////////////////////////

//64
EntityStore :: struct{
    entities : [dynamic]Entity, // 40
    recycled_entities : Small_Circular_Buffer(8), //24
}

@(private)
@(optimization_mode="size")
init_entity_store :: proc() -> EntityStore{
    circular_buffer : Small_Circular_Buffer(8)
    init_circular_buffer(&circular_buffer)

    entity_store := EntityStore{
        entities = make_dynamic_array([dynamic]Entity),
        recycled_entities = circular_buffer,
    }

    return entity_store
}


@(private)
@(optimization_mode="size")
deinit_entity_store :: proc(entity_store : ^EntityStore){
    deinit_circular_buffer(&entity_store.recycled_entities)
    delete_dynamic_array(entity_store.entities)
}

@(optimization_mode="size")
internal_clear_recycled_entities :: proc(entity_store : ^EntityStore){
    clear(&entity_store.recycled_entities)
}

@(private)
@(optimization_mode="speed")
internal_create_entity :: proc(entity_store : ^EntityStore) -> Entity{

    entity : Entity = INVALID_ENTITY

    if contains(&entity_store.recycled_entities){
        recycled_entity := dequeue(&entity_store.recycled_entities)
        entity.id = recycled_entity.id

        entity_store.entities[recycled_entity.id] = entity

    }else{
        current_entity_id := len(entity_store.entities)
        entity.id = current_entity_id
        append(&entity_store.entities, entity)
    }

    return entity
}

@(private)
@(optimization_mode="speed")
internal_destroy_entity :: proc(entity_store : ^EntityStore, entity : Entity){
    entity_store.entities[entity.id] = INVALID_ENTITY
    enqueue(&entity_store.recycled_entities, entity)
}

//////////////////////////////////////////////////////////////////

///////////////////// Component Store ///////////////////////////

ComponentStore :: struct #align 64 { // 40
    sparse : []int, // 16  entity_indices
    entities : rawptr,
    components : rawptr, //8 component list
    len : int,  //8  length of entity and component list
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
    raw_components,_ := mem.alloc(size_of(type) * DEFAULT_MAX_ENTITY_WITH_COMPONENT, 64)
    raw_entities,_ := mem.alloc(size_of(Entity) * DEFAULT_MAX_ENTITY_WITH_COMPONENT, 64)
    sparse := make_slice([]int, DEFAULT_MAX_ENTITY_WITH_COMPONENT)

    //len(sparse) << 3 is a faster of sizeof(int) * len(sparse) where sizeof(int) == 8 
    runtime.memset(&sparse[0], -1,len(sparse) << 3)

    return ComponentStore{
        sparse = sparse,
        entities = raw_entities,
        components = raw_components,
        len = 0,
    }
}

@(private)
@(optimization_mode="size")
internal_insert_component :: proc(component_storage : ^ComponentStore, entity : Entity, component : $T) #no_bounds_check{
    
    //Assert here or we will get undefined behaviour.

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


// Get the specified component from the entity. Doesn't check and handle if the entity has or has not the component.
// It assumes the it has the component. validation is passed to the user. Call has_component function if the end user is unsure.
@(private)
@(optimization_mode="speed")
internal_get_component :: proc(component_storage : ^ComponentStore, entity : Entity, $component : typeid) ->(retrieved_comp : ^component, valid : bool) #optional_ok #no_bounds_check{
    //assert(component_storage.type == component, "trying to fetch a different component type from the component storage. Component storage just handle one type of component.")    
    
    dense_index := component_storage.sparse[entity.id]
    retrieved_comp = &([^]component)(component_storage.components)[dense_index]

    return
}

@(private)
@(optimization_mode="speed")
internal_get_entity :: proc(component_storage : ^ComponentStore, index : int) -> (retrieved_entity : Entity, valid : bool) #optional_ok #no_bounds_check{
    dense_index := component_storage.sparse[index]
    retrieved_entity = ([^]Entity)(component_storage.entities)[dense_index]
   
    return
}

// Get the specified component from the entity. Doesn't check and handle if the entity has or has not the component.
// It assumes the it has the component. validation is passed to the user. Call has_component function if the end user is unsure.
@(private)
@(optimization_mode="speed")
internal_set_component :: proc(component_storage : ^ComponentStore, entity : Entity, component : $T) #no_bounds_check {
    
    local_component := component

    dense_id := component_storage.sparse[entity.id]
    comp_ptr :^u8= ([^]u8)(component_storage.components)[dense_id * size_of(component):] 

    comp_ptr^ = (cast(^u8)(&local_component))^
}


//TODO: khal can we remove component parameter and just use infer the type of component in this ComponentStore
@(private)
@(optimization_mode="size")
internal_remove_component :: proc(component_storage : ^ComponentStore, entity : Entity, $component : typeid) -> (removed_component : component, valid : bool) #optional_ok{

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

    removed_component = removed_comp_ptr[0]

    removed_comp_ptr = last_comp_ptr
    
    return
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
internal_retrieve_entities_with_component :: #force_inline proc(component_storage : ^ComponentStore) -> []Entity #no_bounds_check{
    return ([^]Entity)(component_storage.entities)[:component_storage.len]
}

@(private)
internal_swap_value :: proc(component_storage : ^ComponentStore, dst_entity, src_entity : Entity, component_type : typeid){

    dst_id := component_storage.sparse[dst_entity.id]
    src_id := component_storage.sparse[src_entity.id]

    src_entity_ptr :^Entity = ([^]Entity)(component_storage.entities)[src_id:]
    dst_entity_ptr :^Entity = ([^]Entity)(component_storage.entities)[dst_id:]

    dst_entity_ptr^ = src_entity
    src_entity_ptr^ = dst_entity


    //slice.ptr_swap_non_overlapping(([^]u8)(component_storage.components)[dst_id:],([^]u8)(component_storage.components)[src_id:], size_of(component_type))

    //Swap the component and the entity.
    //Swap the sparse to keep it up to date    
    slice.ptr_swap_non_overlapping(&component_storage.sparse[dst_entity.id],&component_storage.sparse[src_entity.id], size_of(int))


}

///////////////////////////////////////////////////////////

test :: proc(){

    // fmt.println("Size and Align Of EntityStore: ",size_of(EntityStore), align_of(EntityStore))

    // a : Test_Struct
    // a.b = 30
    // c : Test_Struct
    // c.b = 55
    
    // l : Test_Struct
    // l.b = 200
    //  sparse_storage := init_component_store(f64)
    //  entity : Entity = {7, 2}
    


    // entity_2 : Entity = {1,2}
    // entity_3 := Entity{4, 4}
    // a : GlobalDynamicPSConstantBuffer = {4.0, 3.0}
    // internal_insert_component(&sparse_storage, entity,4.0)


    // // fmt.println()
    //  fmt.println("Get Component", internal_retrieve_components(&sparse_storage, f64 ))
    // fmt.println("Get Component", internal_get_component(&sparse_storage,entity, Test_Struct ))

    // fmt.println("Get other Component before ", internal_get_component(&sparse_storage, entity_2, Test_Struct))
    // fmt.println("Get Component before removed", internal_get_component(&sparse_storage,entity, Test_Struct ))
    // // r := remove_component(&sparse_storage, entity_2, Test_Struct)
    // // fmt.println("Removed component ", r)
    // fmt.println("Get Component after removed", internal_get_component(&sparse_storage,entity, Test_Struct ))
    // fmt.println("Get other Component after removed", internal_get_component(&sparse_storage, entity_2, Test_Struct))
    

    // // b := Test_Struct{
    // //     b = 100,
    // // }
    
    // // set_component(&sparse_storage, entity_2, b)

    // fmt.println(internal_retrieve_entities_with_component(&sparse_storage))
    // fmt.println(internal_retrieve_components(&sparse_storage, Test_Struct))



    // queue : Small_Circular_Buffer(8)
    // init_circular_buffer(&queue)
    // enqueue(&queue, Entity{0,1})
    // enqueue(&queue, Entity{0,2})
    // enqueue(&queue, Entity{0,3})
    // enqueue(&queue, Entity{0,4})
    // enqueue(&queue, Entity{0,5})
    // enqueue(&queue, Entity{0,6})
    // enqueue(&queue, Entity{0,7})
    // enqueue(&queue, Entity{0,8})

    // fmt.println(dequeue(&queue))
    // fmt.println(dequeue(&queue))
    // fmt.println(dequeue(&queue))
    // fmt.println(dequeue(&queue))
    // fmt.println(dequeue(&queue))
    // fmt.println(dequeue(&queue))
    // fmt.println(dequeue(&queue))
    // fmt.println(dequeue(&queue))

    entity : Entity = {0, 2}
    entity1 : Entity = {1, 2}
    entity2 : Entity = {2, 2}

    entity3 :Entity = {10 , 4}
    entity4 :Entity = {20 , 4}

    // a : Test_Struct
    // a.b = 10

    // b : Test_Struct
    // b.b = 20

    // c : Test_Struct
    // c.b = 30

    world := init_world()

    f := ECS_Query_Dec{
        all = []typeid{ f64, int},
    }

    register(world, f64)
    register(world, int)

    add_component(world,entity4, 5)
    add_component(world,entity, 5)
    add_component(world,entity2, 10)

    add_component(world, entity1, 3.3)
    add_component(world, entity, 5.5)
    add_component(world, entity2, 2.0)
    add_component(world,entity3, 1.14)


    group(world, f)

   


    fmt.println("\n\n")
    fmt.println("F64 struct: ",get_entities_with_component(world, f64))
    fmt.println("Int: ",get_entities_with_component(world, int))


  




    //get_entities_with_components(&word, Test_Struct)
}
