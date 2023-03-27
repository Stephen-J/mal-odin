package main

import "core:fmt"
import "core:os"
import "core:strings"
import "../src"


read :: proc(form : string) -> string {
  return form
}

eval :: proc(form : string) -> string {
  return form
}

print :: proc(form : string) -> string {
  return form
}

rep :: proc(form : string) -> string {
  read_string()
  return print(eval(read(form)))
}


main :: proc() { 
  data := []u8{0}
  form_builder := strings.builder_make()
  defer strings.builder_destroy(&form_builder)
  for {
    os.write_string(os.stdout,"user> ")
    os.read(os.stdin,data)
    for ; data[0] != 10 ; {
      strings.write_byte(&form_builder,data[0])
      os.read(os.stdin,data)
    }
    fmt.println(rep(strings.to_string(form_builder)))
    strings.builder_reset(&form_builder)
  }
}
