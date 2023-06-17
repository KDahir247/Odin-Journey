package ecs

/* 
NOTE:
I know, code duplication...

There is no way to take in an array of types, and it will not be added to the language. 
The only reasonable solution is this...
*/

get_components_2 :: proc(ctx: ^Context, entity: Entity, $A, $B: typeid) -> (^A, ^B, [2]ECS_Error) {
  a, err1 := get_component(ctx, entity, A)
  b, err2 := get_component(ctx, entity, B)
  return a, b, {}
}

get_components_3 :: proc(ctx: ^Context, entity: Entity, $A, $B, $C: typeid) -> (^A, ^B, ^C, [3]ECS_Error) {
  a, err1 := get_component(ctx, entity, A)
  b, err2 := get_component(ctx, entity, B)
  c, err3 := get_component(ctx, entity, C)
  return a, b, c, {}
}

get_components_4 :: proc(ctx: ^Context, entity: Entity, $A, $B, $C, $D: typeid) -> (^A, ^B, ^C, ^D, [4]ECS_Error) {
  a, err1 := get_component(ctx, entity, A)
  b, err2 := get_component(ctx, entity, B)
  c, err3 := get_component(ctx, entity, C)
  d, err4 := get_component(ctx, entity, D)
  return a, b, c, d, {}
}

get_components_5 :: proc(ctx: ^Context, entity: Entity, $A, $B, $C, $D, $E: typeid) -> (^A, ^B, ^C, ^D, ^E, [5]ECS_Error) {
  a, err1 := get_component(ctx, entity, A)
  b, err2 := get_component(ctx, entity, B)
  c, err3 := get_component(ctx, entity, C)
  d, err4 := get_component(ctx, entity, D)
  e, err5 := get_component(ctx, entity, E)
  return a, b, c, d, e, {}
}

get_components_2_unchecked :: proc(ctx: ^Context, entity: Entity, $A, $B: typeid) -> (^A, ^B) {
  a := get_component_unchecked(ctx, entity, A)
  b := get_component_unchecked(ctx, entity, B)
  return a, b
}

get_components_3_unchecked :: proc(ctx: ^Context, entity: Entity, $A, $B, $C: typeid) -> (^A, ^B, ^C) {
  a := get_component_unchecked(ctx, entity, A)
  b := get_component_unchecked(ctx, entity, B)
  c := get_component_unchecked(ctx, entity, C)
  return a, b, c
}

get_components_4_unchecked :: proc(ctx: ^Context, entity: Entity, $A, $B, $C, $D: typeid) -> (^A, ^B, ^C, ^D) {
  a, err1 := get_component_unchecked(ctx, entity, A)
  b, err2 := get_component_unchecked(ctx, entity, B)
  c, err3 := get_component_unchecked(ctx, entity, C)
  d, err4 := get_component_unchecked(ctx, entity, D)
  return a, b, c, d
}

get_components_5_unchecked :: proc(ctx: ^Context, entity: Entity, $A, $B, $C, $D, $E: typeid) -> (^A, ^B, ^C, ^D, ^E) {
  a, err1 := get_component_unchecked(ctx, entity, A)
  b, err2 := get_component_unchecked(ctx, entity, B)
  c, err3 := get_component_unchecked(ctx, entity, C)
  d, err4 := get_component_unchecked(ctx, entity, D)
  e, err5 := get_component_unchecked(ctx, entity, E)
  return a, b, c, d, e
}
 

get_components :: proc {
  get_components_2, 
  get_components_3,
  get_components_4,
  get_components_5,
}


get_components_unchecked :: proc{
  get_components_2_unchecked, 
  get_components_3_unchecked,
  get_components_4_unchecked,
  get_components_5_unchecked,
}

