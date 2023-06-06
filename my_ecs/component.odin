package my_ecs

component_storage :: struct{
    entities : [dynamic]Entity,
    components : [dynamic]u8,
    len : uint,
    cap : uint,
    //sparse : SparseArray,
}

insert :: proc(comp_storage : ^component_storage, entity, int, component : $T) -> T{
    append_elem()
}
