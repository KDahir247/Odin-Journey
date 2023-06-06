package ecs

import "core:runtime"
import "core:container/queue"
import "core:slice"

Component_List :: struct {
  type: typeid,
  data: ^runtime.Raw_Dynamic_Array,
  entity_indices: map[Entity]uint,
}

@private
register_component :: proc(ctx: ^Context, $T: typeid) -> ECS_Error {
  is_type_a_key := T in ctx.component_map
  if is_type_a_key {
    return .COMPONENT_IS_ALREADY_REGISTERED
  }

  array := new([dynamic]T)
  ctx.component_map[T] = {
    type = T,
    data = cast(^runtime.Raw_Dynamic_Array)array,
  }
  array^ = make_dynamic_array([dynamic]T)

  return .NO_ERROR
}

add_component :: proc(ctx: ^Context, entity: Entity, component: $T) -> (^T, ECS_Error) {
  register_component(ctx, T)

  if has_component(ctx, entity, T) {
    return nil, .ENTITY_ALREADY_HAS_THIS_COMPONENT
  } 
  array := cast(^[dynamic]T)ctx.component_map[T].data
  comp_map := &ctx.component_map[T]
  
  // Add a new component to the component array.
  append_elem(array, component) 
  // Map the entity to the new index, so we can lookup the component index later,
  comp_map.entity_indices[entity] = len(array) - 1

  return &array[comp_map.entity_indices[entity]], .NO_ERROR
}

add_component_unchecked :: proc(ctx: ^Context, entity: Entity, component: $T) -> ^T{
  register_component(ctx, T)

  #no_bounds_check{
    array := cast(^[dynamic]T)ctx.component_map[T].data
    comp_map := &ctx.component_map[T]
  
    // Add a new component to the component array.
    append_elem(array, component) 
    // Map the entity to the new index, so we can lookup the component index later,
    comp_map.entity_indices[entity] = len(array) - 1

    return &array[comp_map.entity_indices[entity]]
  }
}

has_component :: proc(ctx: ^Context, entity: Entity, T: typeid) -> bool {
  return entity in (&ctx.component_map[T]).entity_indices
}

@private
remove_component_with_typeid :: proc(ctx: ^Context, entity: Entity, type_id: typeid) -> ECS_Error {
  using ctx.entities

  if !has_component(ctx, entity, type_id) {
    return .ENTITY_DOES_NOT_HAVE_THIS_COMPONENT
  }
  index := ctx.component_map[type_id].entity_indices[entity]

  array_len := ctx.component_map[type_id].data^.len
  array := ctx.component_map[type_id].data^.data
  comp_map := ctx.component_map[type_id]

  info := type_info_of(type_id)
  struct_size := info.size
  array_in_bytes := slice.bytes_from_ptr(array, array_len * struct_size)

  byte_index := int(index) * struct_size
  last_byte_index := (len(array_in_bytes)) - struct_size  
  e_index := comp_map.entity_indices[entity]
  e_back := uint(array_len - 1)
  if e_index != e_back {    
    slice.swap_with_slice(array_in_bytes[byte_index: byte_index + struct_size], array_in_bytes[last_byte_index:])
    // TODO: Remove this and replace it with something that dosen't have to do a lot of searching.
    for _, value in &comp_map.entity_indices {
      if value == e_back { value = e_index }
    }
  }

  delete_key(&comp_map.entity_indices, entity)

  return .NO_ERROR
}

remove_component :: proc(ctx: ^Context, entity: Entity, $T: typeid) -> ECS_Error {
  return remove_component_with_typeid(ctx, entity, T)
}

get_component :: proc(ctx: ^Context, entity: Entity, $T: typeid) -> (component: ^T, error: ECS_Error) {
  
  if !has_component(ctx, entity, T) {
    return nil, .ENTITY_DOES_NOT_HAVE_THIS_COMPONENT
  }

  array := cast(^[dynamic]T)ctx.component_map[T].data
  index, is_entity_a_key := ctx.component_map[T].entity_indices[entity]
  
  if !is_entity_a_key {
    return nil, .ENTITY_DOES_NOT_MAP_TO_ANY_INDEX
  }

  return &array[index], .NO_ERROR
}

get_component_unchecked :: proc(ctx: ^Context, entity: Entity, $T: typeid) -> ^T{
  #no_bounds_check{
        array := cast(^[dynamic]T)ctx.component_map[T].data
        index, _ := ctx.component_map[T].entity_indices[entity]
        return &array[index]
  }
}


get_component_list :: proc(ctx: ^Context, $T: typeid) -> []T {
  array := cast(^[dynamic]T)ctx.component_map[T].data

  return array[:]
}



set_component :: proc(ctx: ^Context, entity: Entity, component: $T) -> ECS_Error {
  if !has_component(ctx, entity, T) {
    return .COMPONENT_NOT_REGISTERED
  } 
  index, is_entity_a_key := ctx.component_map[T].entity_indices[entity]

  if !is_entity_a_key {
    return .ENTITY_DOES_NOT_MAP_TO_ANY_INDEX
  }
  array := cast(^[dynamic]T)ctx.component_map[T].data
  array[index] = component
  return .NO_ERROR
}

set_component_unchecked :: proc(ctx: ^Context, entity: Entity, component: $T){
  #no_bounds_check{
    index, is_entity_a_key := ctx.component_map[T].entity_indices[entity]
    array := cast(^[dynamic]T)ctx.component_map[T].data
    array[index] = component
  }
}