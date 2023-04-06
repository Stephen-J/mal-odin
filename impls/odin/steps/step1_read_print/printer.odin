package main

import "core:strconv"
import "core:strings"
import "core:fmt"

print_string :: proc(t : MalType) -> string {
  value : string
  switch type in t {
    case Symbol : value = t.(Symbol).name
    case String : value = strings.join([]string{"\"",t.(String).value,"\""},"")
    case Number : buffer := [100]u8{}
                  value = strconv.itoa(buffer[:],t.(Number).value)
    case Nil : value = "nil"
    case True : value = "true"
    case False : value = "false"
    case Keyword : value = strings.join([]string{":",t.(Keyword).name},"")
    case List : list := t.(List)
                items := [dynamic]string{}
                for mal_type in list.items{
                  append(&items,print_string(mal_type))
                }
                value = strings.join([]string{"(",strings.join(items[:]," "),")"},"")
  }
  return strings.clone(value)
}
