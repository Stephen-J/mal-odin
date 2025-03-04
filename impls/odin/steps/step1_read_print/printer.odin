package main

import "core:fmt"
import "core:strconv"
import "core:unicode/utf8"
import "core:strings"

print_string :: proc(type : MalType) -> string {
  result : string
  switch v in type {
    case String :
      escaped := escape_runes(v.runes[:])
      defer delete(escaped)
      s := utf8.runes_to_string(escaped[:])
      defer delete(s)
      result = fmt.aprint("\"",s,"\"",sep = "")
    case Number :
      result = fmt.aprint(v.val)
    case Map :
      tmp := [dynamic]string{}
      defer {
        for t in tmp do delete(t)
        delete(tmp)
      }
      for key_form,index in v.keys {
        append(&tmp,print_string(key_form))
        append(&tmp,print_string(v.values[index]))
      }
      items := strings.join(tmp[:]," ")
      defer delete(items)
      result = fmt.aprint("{",items,"}",sep = "")
    case Vector :
      tmp := [dynamic]string{}
      defer {
        for t in tmp do delete(t)
        delete(tmp)
      }
      for form in v.items{
        append(&tmp,print_string(form))
      }
      items := strings.join(tmp[:]," ")
      defer delete(items)
      result = fmt.aprint("[",items,"]",sep = "")
    case List :
      tmp := [dynamic]string{}
      defer{
        for t in tmp do delete(t)
        delete(tmp)
      }
      for form in v.items {
        append(&tmp,print_string(form))
      }
      items := strings.join(tmp[:]," ")
      defer delete(items)
      result = fmt.aprint("(",items,")",sep = "")
    case Symbol :
      result = fmt.aprint(v.name)
    case Keyword :
      result = fmt.aprint(":",v.name,sep = "")
    case Nil : result = fmt.aprint("nil")
    case True : result = fmt.aprint("true")
    case False : result = fmt.aprint("false")
    case :  result = "Unknown"
  }
  return result
}

print_error :: proc(err : Error) -> string {
  error_string : string
  switch e in err {
    case Token_Not_Matched :
      error_string = fmt.aprint(e.started," unbalanced ")
      
  }
  return error_string
}
