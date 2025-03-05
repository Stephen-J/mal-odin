package main
import "core:fmt"
import "core:os"
import "core:bufio"
import "core:strings"
import "core:mem"



read :: proc(src : string) -> ([dynamic]MalType,Error){
  return read_string(src)
}

eval :: proc(forms : [dynamic]MalType,err : Error) -> ([dynamic]MalType,Error){
  if err != nil do return forms,err
  return forms,nil
}

print :: proc(forms : [dynamic]MalType,err : Error) -> (string,Error){
  defer {
    for form in forms do type_destroy(form)
    delete(forms)
  }

  if err != nil do return "",err
  results := [dynamic]string{}
  defer {
    for result in results do delete(result)
    delete(results)
  }
  for form in forms{
    append(&results,print_string(form))
  }
  return strings.join(results[:]," "),nil
}

rep :: proc(src : string) -> (valid_string : string,err : Error) {
  s := print(eval(read(src))) or_return 
  return s,nil
}

when ODIN_DEBUG {
  track : mem.Tracking_Allocator
}

main :: proc(){
  when ODIN_DEBUG {
    //track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)
    defer {
      if len(track.allocation_map) > 0 {
        fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
        for _, entry in track.allocation_map {
          fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
        }
      }
      if len(track.bad_free_array) > 0 {
        fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
        for entry in track.bad_free_array {
          fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
        }
      }
      mem.tracking_allocator_destroy(&track)
    }
  } 
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
    if len(src) > 1 {
      trimmed,_ := strings.substring(src,0,len(src) - 1)
      result,err := rep(trimmed)
      defer delete(result)
      if(err == nil){
        fmt.println(result)
      } else {
        e := print_error(err)
        defer delete(e)
        fmt.println(e)
      }
    } else {
      fmt.println("")
      break
    }
  }
}
