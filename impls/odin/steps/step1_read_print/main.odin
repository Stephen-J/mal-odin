package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:io"


read :: proc(src : string) -> MalType {
  reader : strings.Reader
  return read_string(strings.to_reader(&reader,src))
}

eval :: proc(src : MalType) -> MalType {
  return src
}

print :: proc(src : MalType) -> string {
  str := print_string(src)
  return str;
}

rep :: proc(src : string) -> string {
  str := print(eval(read(src)))
  return str
}


main :: proc() { 
  data := []u8{0}
  src := strings.builder_make()
  defer strings.builder_destroy(&src)
  for {
    os.write_string(os.stdout,"user> ")
    os.read(os.stdin,data)
    for ; data[0] != 10 ; {
      strings.write_byte(&src,data[0])
      os.read(os.stdin,data)
    }
    fmt.println(rep(strings.to_string(src)))
    strings.builder_reset(&src)
  }
}
