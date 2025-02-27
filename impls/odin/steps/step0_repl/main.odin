package main
import "core:fmt"
import "core:os"
import "core:bufio"
import "core:strings"



read :: proc(src : string) -> string{
  return src
}

eval :: proc(src : string) -> string{
  return src
}

print :: proc(src : string) -> string{
  return src
}

rep :: proc(src : string) -> string{
  return print(eval(read(src)))
}


main :: proc(){
  stdin_stream := os.stream_from_handle(os.stdin)
  stdin : bufio.Reader
  bufio.reader_init(&stdin,stdin_stream)
  defer bufio.reader_destroy(&stdin)

  stdout_stream := os.stream_from_handle(os.stdout)
  stdout : bufio.Writer
  bufio.writer_init(&stdout,stdout_stream)
  defer bufio.writer_destroy(&stdout)
  for {
    bufio.writer_write_string(&stdout,"user> ")
    bufio.writer_flush(&stdout)
    src,error := bufio.reader_read_string(&stdin,10)
    defer delete(src)
    trimmed,_ := strings.substring(src,0,len(src) - 1)
    fmt.println(trimmed)
  }
}
