package journey

import "core:slice"
import "core:runtime"
import "core:fmt"
import "core:intrinsics"
import "core:mem"
Test_Struct :: struct{
    b : int,
}


//size must have all bit set to one plus 1. eg. 0b0111 == 7 then we add 1 so 8
@(private)
Small_Circular_Buffer :: struct($size : uint){
    buffer : []Entity, // 16 byte
    // HI 32 bit are the tail the LO 32 bit are the head
    shared_index : uint, // 8
}

// //defer_in
init_circular_buffer :: proc(q : ^$Q/Small_Circular_Buffer($T)){
    q^.buffer = make_slice([]Entity, T)
    q.shared_index = 0
}

deinit_circular_buffer :: proc(q : ^$Q/Small_Circular_Buffer($T)){
    delete_slice(q^.buffer)
    q.shared_index = 0
}

//TODO: khal break dependencies.
enqueue :: proc(q : ^$Q/Small_Circular_Buffer($T), entity : Entity){
    head := (q.shared_index & 0xFFFFFFFF00000000) >> 32

    q.buffer[head] = entity

    next_head := (head + 1) & (T - 1)
    q.shared_index = (next_head << 32) | (q.shared_index & 0xFFFFFFFF)
}

dequeue :: proc(q : ^$Q/Small_Circular_Buffer($T)) -> Entity{
    tail := (q.shared_index & 0xFFFFFFFF)

    value := q.buffer[tail]

    next_tail := (tail + 1) & (T - 1)
    q.shared_index = (q.shared_index & 0xFFFFFFFF00000000) | next_tail
    
    return value
}

clear :: proc(q : ^$Q/Small_Circular_Buffer($T)){
    q.shared_index = 0
    intrinsics.mem_zero(raw_data(q.buffer), size_of(Entity) * len(q.buffer))
}

contains :: proc(q : ^$Q/Small_Circular_Buffer($T)) -> bool{
    head := (q.shared_index & 0xFFFFFFFF00000000) >> 32
    tail := (q.shared_index & 0xFFFFFFFF)
    
    return head > tail
}

DEFAULT_MAX_ENTITY_WITH_COMPONENT :: 2048
INVALID_ENTITY :: Entity{-1, 0}

//16
Entity :: struct{
    id : int, // 8
    version : uint, // 8
}

//////////////////////////// World /////////////////////////////////////

//80
World :: struct{
    entities_store : EntityStore, // 64
    components_store : map[typeid]ComponentStore, // 32
    //We want the resource to be 32 in size
    //Resource we have to make a way to allow a array of generic type. And only on resource is allowed of the type
    //resource : u32,
}

get_entities_with_component :: proc(world : ^World, $component : typeid) -> []Entity{
    return retrieve_entities_with_component(world.components_store[component])
} 

///////////////////////////////////////////////////////////////////

//////////////////////// Entity Store /////////////////////////////

//64
EntityStore :: struct{
    entities : [dynamic]Entity, // 40
    recycled_entities : Small_Circular_Buffer(8), //24
}


init_entity_store :: proc() -> EntityStore{

    circular_buffer : Small_Circular_Buffer(8)
    init_circular_buffer(&circular_buffer)

    entity_store := EntityStore{
        entities = make_dynamic_array([dynamic]Entity),
        recycled_entities =circular_buffer,
    }


    return entity_store
}


deinit_entity_store :: proc(entity_store : ^EntityStore){
    deinit_circular_buffer(&entity_store.recycled_entities)
    delete_dynamic_array(entity_store.entities)
}

clear_recycled_entities :: proc(entity_store : ^EntityStore){
    clear(&entity_store.recycled_entities)
}

create_entity :: proc(entity_store : ^EntityStore) -> Entity{

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

destroy_entity :: proc(entity_store : ^EntityStore, entity : Entity){
    entity_store.entities[entity.id] = INVALID_ENTITY
    enqueue(&entity_store.recycled_entities, entity)
}

//////////////////////////////////////////////////////////////////

///////////////////// Component Store ///////////////////////////

//40
ComponentStore :: struct #align 64 {
    sparse : []int, // 16
    entities : ^Entity, //8 
    components : ^u8, //8
    len : int,  //8
}


deinit_component_store :: proc(comp_storage : ComponentStore){
    delete_slice(comp_storage.sparse)
    free(comp_storage.components)
    free(comp_storage.entities)
}

init_component_store :: proc(type : typeid, size := DEFAULT_MAX_ENTITY_WITH_COMPONENT) -> ComponentStore{
    raw_components,_ := mem.alloc(size_of(type) * DEFAULT_MAX_ENTITY_WITH_COMPONENT, 64)
    raw_entities,_ := mem.alloc(size_of(Entity) * DEFAULT_MAX_ENTITY_WITH_COMPONENT, 64)
    sparse := make_slice([]int, DEFAULT_MAX_ENTITY_WITH_COMPONENT)

    //slice.fill(sparse, -1)
    runtime.memset(&sparse[0], -1, size_of(sparse[0]) * len(sparse))
    //fmt.println(sparse)

    return ComponentStore{
        sparse = sparse,
        entities = cast(^Entity)(raw_entities),
        components = cast(^u8)(raw_components),
        len = 0,
    }
}

insert_component :: proc(component_storage : ^ComponentStore, entity : Entity, component : $T){
    //assert(component_storage.type == type_of(component) && entity.id < len(component_storage.sparse), "...")
    
    local_component := component
    local_entity := entity

    dense_id := component_storage.sparse[entity.id]
    has_mask := has_component(component_storage, entity)
    incr_mask := (1.0 -  has_mask)

    dense_index := (component_storage.len * incr_mask) + (dense_id * has_mask)

    component_storage.sparse[entity.id] = dense_index

    comp_ptr := slice.ptr_add(component_storage.components,dense_index * size_of(component))
    ent_ptr := slice.ptr_add(component_storage.entities, dense_index)
    
    comp_ptr^ = (cast(^u8)(&local_component))^
    ent_ptr^ = local_entity

    component_storage.len += incr_mask
}

get_component :: proc(component_storage : ^ComponentStore, entity : Entity, $component : typeid) ->(retrieved_comp : ^component, valid : bool) #optional_ok{
    //assert(component_storage.type == component, "trying to fetch a different component type from the component storage. Component storage just handle one type of component.")    
    
    dense_index := component_storage.sparse[entity.id]

    if dense_index != -1{
        retrieved_comp = &([^]component)(component_storage.components)[dense_index]
    }

    return
}


//
set_component :: proc(component_storage : ^ComponentStore, entity : Entity, component : $T) {
    local_component := component

    assert(component_storage.sparse[entity.id] != -1, "")

    dense_id := component_storage.sparse[entity.id]
    comp_ptr := slice.ptr_add(component_storage.components,dense_id * size_of(component))

    comp_ptr^ = (cast(^u8)(&local_component))^
}

//TODO: khal this need working on
remove_component :: proc(component_storage : ^ComponentStore, entity : Entity, $component : typeid) -> (removed_component : component, valid : bool) #optional_ok{

    //TODO: should i put the removed entity in the last element then decrement the len by one. So if we insert the same thing we removed then it is technically cached.. 
    // And should i also put the removed component in the last element then decrement the len by one, So it is is a sense cached.
        
    dense_id := component_storage.sparse[entity.id]
        
    component_storage.len -= 1

    last_entity := ([^]Entity)(component_storage.entities)[component_storage.len]

    ent_ptr := slice.ptr_add(component_storage.entities, dense_id)
    ent_ptr^ = last_entity

    //We need to reorder the sparse set 
    //TODO: can we remove the if statement here as well?
    if dense_id < component_storage.len{
        component_storage.sparse[last_entity.id] = dense_id
        component_storage.sparse[entity.id] = -1
    }

    removed_comp_ptr := ([^]component)(component_storage.components)[dense_id:]
    last_comp_ptr := ([^]component)(component_storage.components)[component_storage.len:]

    removed_component = removed_comp_ptr[0]

    intrinsics.mem_copy(removed_comp_ptr,last_comp_ptr,1)
    return
}


@(optimization_mode="speed")
has_component :: #force_inline proc(component_storage : ^ComponentStore, entity : Entity) -> int{
    dense_id := component_storage.sparse[entity.id]

    return clamp(dense_id + 1, 0, 1)
}

retrieve_components :: proc(component_storage : ^ComponentStore, $component_type : typeid) -> []component_type{
    //assert(component_storage.type == component_type)

    return ([^]component_type)(component_storage.components)[:component_storage.len]
}

retrieve_entities_with_component :: proc(component_storage : ^ComponentStore) -> []Entity{
    return ([^]Entity)(component_storage.entities)[:component_storage.len]
}


///////////////////////////////////////////////////////////

test :: proc(){

    fmt.println("Size and Align Of EntityStore: ",size_of(EntityStore), align_of(EntityStore))

    a : Test_Struct
    a.b = 30
    c : Test_Struct
    c.b = 55
    
    sparse_storage := init_component_store(Test_Struct)
    entity : Entity = {0, 2}
    
    entity_2 : Entity = {1,2}
    insert_component(&sparse_storage, entity, a)
    insert_component(&sparse_storage, entity_2, c)


    fmt.println()
    fmt.println("Get Component", get_component(&sparse_storage,entity, Test_Struct ))
    fmt.println("Get Component", get_component(&sparse_storage,entity, Test_Struct ))
    //fmt.println("Get Component", get_component(&sparse_storage,{30, 0}, Test_Struct ))
    //fmt.println("Get Component", get_component(&sparse_storage,{30, 0}, Entity ))

    fmt.println("Get other Component before ", get_component(&sparse_storage, entity_2, Test_Struct))
    fmt.println("Get Component before removed", get_component(&sparse_storage,entity, Test_Struct ))
    r := remove_component(&sparse_storage, entity, Test_Struct)
    fmt.println("Removed component ", r)
    fmt.println("Get Component after removed", get_component(&sparse_storage,entity, Test_Struct ))
    fmt.println("Get other Component after", get_component(&sparse_storage, entity_2, Test_Struct))
    

    b := Test_Struct{
        b = 100,
    }
    
    set_component(&sparse_storage, entity_2, b)

    fmt.println(retrieve_entities_with_component(&sparse_storage))
    fmt.println(retrieve_components(&sparse_storage, Test_Struct))



    queue : Small_Circular_Buffer(8)
    init_circular_buffer(&queue)
    enqueue(&queue, Entity{0,1})
    enqueue(&queue, Entity{0,2})
    enqueue(&queue, Entity{0,3})
    enqueue(&queue, Entity{0,4})
    enqueue(&queue, Entity{0,5})
    enqueue(&queue, Entity{0,6})
    enqueue(&queue, Entity{0,7})
    enqueue(&queue, Entity{0,8})
    fmt.println(queue)

    fmt.println(dequeue(&queue))
    fmt.println(dequeue(&queue))
    fmt.println(dequeue(&queue))
    fmt.println(dequeue(&queue))
    fmt.println(dequeue(&queue))
    fmt.println(dequeue(&queue))
    fmt.println(dequeue(&queue))
    fmt.println(dequeue(&queue))


}
