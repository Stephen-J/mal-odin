package main

import "core:fmt"
import "core:strconv"
import "core:unicode/utf8"
import "core:strings"

print_string :: proc(type : MalType) -> string {
  result : string
  switch v in type {
    case String :
      result = utf8.runes_to_string(v.runes[:])
    case Number :
      result = fmt.aprint(v.val)
    case Map :
      tmp := [dynamic]string{}
      defer delete(tmp)
      for key_form,index in v.keys {
        append(&tmp,print_string(key_form))
        append(&tmp,print_string(v.values[index]))
      }
      result = fmt.aprint("{",strings.join(tmp[:]," "),"}",sep = "")
    case Vector :
      tmp := [dynamic]string{}
      defer delete(tmp)
      for form in v.items{
        append(&tmp,print_string(form))
      }
      result = fmt.aprint("[",strings.join(tmp[:]," "),"]",sep = "")
    case List :
      tmp := [dynamic]string{}
      defer delete(tmp)
      for form in v.items {
        append(&tmp,print_string(form))
      }
      result = fmt.aprint("(",strings.join(tmp[:]," "),")",sep = "")
    case Symbol :
      result = fmt.aprint(v.name)
    case Keyword :
      result = fmt.aprint(":",v.name,sep = "")
    case :
      result = "Unknown"
  }
  return result
}
