package journey

import "core:slice"
import "core:runtime"
import "core:fmt"
import "core:intrinsics"
import "core:mem"

DEFAULT_MAX_ENTITY_WITH_COMPONENT :: 2048

INVALID_ENTITY :: Entity{-1, 0}

SparseSet :: struct{
    b : int,
}

Entity :: struct{
    id : int,
    version : uint,
}

ComponentStorages :: struct{
    component_storage : [dynamic]ComponentStorage,
    storage_indices : map[typeid]u32,
}

ComponentStorage :: struct #align 64 {
    sparse : []Maybe(Entity),
    entities : ^Entity,
    components : ^u8,
    len : int, 
    type : typeid,
}


@(private)
ptr_index :: proc(p: $P/^$T, x: int) -> T{
    return ([^]T)(p)[x]
}

deinit_component :: proc(comp_storage : ComponentStorage){
    delete_slice(comp_storage.sparse)
    free(comp_storage.components)
    free(comp_storage.entities)
}

init_component_storage :: proc(type : typeid, size := DEFAULT_MAX_ENTITY_WITH_COMPONENT) -> ComponentStorage{
    raw_components,_ := mem.alloc(size_of(type) * DEFAULT_MAX_ENTITY_WITH_COMPONENT, 64)
    raw_entities,_ := mem.alloc(size_of(Entity) * DEFAULT_MAX_ENTITY_WITH_COMPONENT, 64)
    
    sparse := make_slice([]Maybe(Entity), DEFAULT_MAX_ENTITY_WITH_COMPONENT)

    return ComponentStorage{
        sparse = sparse,
        entities = cast(^Entity)(raw_entities),
        components = cast(^u8)(raw_components),
        type = type,
        len = 0,
    }
}

insert_component :: proc(component_storage : ^ComponentStorage, entity : Entity, component : $T){

    assert( component_storage.type == type_of(component) && entity.id < len(component_storage.sparse), "...")
    
    local_component := component
    local_entity := entity

    incr_mask := (1.0 -  has_component(component_storage, entity))

    dense_entity := component_storage.sparse[entity.id].? or_else Entity{component_storage.len, entity.version}
    component_storage.sparse[entity.id] = dense_entity

    comp_ptr := slice.ptr_add(component_storage.components,dense_entity.id * size_of(component))
    comp_ptr^ = (cast(^u8)(&local_component))^

    ent_ptr := slice.ptr_add(component_storage.entities, dense_entity.id)
    ent_ptr^ = local_entity

    component_storage.len += incr_mask
}

get_component :: proc(component_storage : ^ComponentStorage, entity : Entity, $component : typeid) ->(retrieved_comp : Maybe(component), valid : bool) #optional_ok{
    assert(component_storage.type == component, "trying to fetch a different component type from the component storage. Component storage just handle one type of component.")    
    
    dense_entity := component_storage.sparse[entity.id].? or_return 
    retrieved_comp = ([^]component)(component_storage.components)[dense_entity.id]
    return
}

// //TODO: khal this need working on
// remove_component :: proc(component_storage : ^ComponentStorage, entity : Entity){
//     //TODO: don't like the if statement in hot code.
//     if has_component(component_storage, entity) == 1{

//         component_storage.len -= 1

//         dense_entity := component_storage.sparse[entity.id].?
//         component_storage.sparse[entity.id] = nil

//         last_entity := ptr_index(component_storage.entities,component_storage.len)

//         ent_ptr := slice.ptr_add(component_storage.entities, dense_entity.id)
//         ent_ptr^ = last_entity

//         if dense_entity.id < component_storage.len{
//             component_storage.sparse[last_entity.id] = Entity{dense_entity.id, last_entity.version}
//         }

//         removed_comp := slice.ptr_add(component_storage.components,dense_entity.id * size_of(component_storage.type))

//         res := mem.copy(slice.ptr_add(component_storage.components, component_storage.len), removed_comp, size_of(component_storage.type))
        
//         component_storage.components = cast(^u8)(res)

//         // let removed_ptr = self.get_component_ptr::<T>(index);
//         // let removed = removed_ptr.read();

//         // ptr::copy(self.get_component_ptr::<T>(self.len), removed_ptr, 1);
//         // Some(removed)
//         //ent_ptr^ = (cast(^Entity)(&component_storage.len))^
        


//         //TODO: khal implement
//         fmt.println("has component.")
//     }
// }


@(optimization_mode="speed")
has_component :: #force_inline proc(component_storage : ^ComponentStorage, entity : Entity) -> int{

    assert(entity.id != -1, "usage of INVALID_ENTITY constant as the entity.")
    
    dense_entity := component_storage.sparse[entity.id].? or_else INVALID_ENTITY

    return (dense_entity.id >= 0) ? 1 : 0
}

retrieve_components :: proc(component_storage : ^ComponentStorage, $component_type : typeid) -> []component_type{
    assert(component_storage.type == component_type)

    return ([^]component_type)(component_storage.components)[:3]
}

retrieve_entities :: proc(component_storage : ^ComponentStorage) -> []Entity{

    return ([^]Entity)(component_storage.entities)[:3]
}

test :: proc(){
    a : SparseSet
    a.b = 30
    c : SparseSet
    c.b = 55
    
    sparse_storage := init_component_storage(SparseSet)
    entity : Entity = {0, 1}
    
    entity_2 : Entity = {1,2}
    insert_component(&sparse_storage, entity, a)
    insert_component(&sparse_storage, entity_2, c)


    //remove_component(&sparse_storage, entity)

    fmt.println("Get Component", get_component(&sparse_storage,entity, SparseSet ))
    fmt.println("Get Component", get_component(&sparse_storage,entity, SparseSet ))
    fmt.println("Get Component", get_component(&sparse_storage,{30, 0}, SparseSet ))
    fmt.println("Get Component", get_component(&sparse_storage,{30, 0}, Entity ))


    // tester : bool = false
     fmt.println(retrieve_entities(&sparse_storage))
     fmt.println(retrieve_components(&sparse_storage, SparseSet))

}
