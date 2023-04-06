package main
import "core:fmt"
import "core:strings"
import "core:io"
import "core:bufio"
import "core:bytes"
import "core:strconv"
import "core:time"

Reader :: struct {
  tokens : []string,
  position : int,
  length : int,
}

reader_init :: proc(reader : ^Reader,tokens : []string) {
  reader.tokens = tokens
  reader.position = 0
  reader.length = len(tokens)
}

reader_consume :: proc(reader : ^Reader) -> string {
  using reader
  next := tokens[position]
  position += 1
  return next
}

reader_peek :: proc(reader : ^Reader) -> string {
  using reader
  return tokens[position]
}

reader_has_next :: proc(reader : ^Reader) -> bool {
  using reader
  return position < length
}

reader_push_back :: proc(reader : ^Reader) {
  using reader
  position -= 1
}

is_whitespace :: proc(c : u8) -> bool {
  switch c {
    case 9,10,13,32,44 : return true
    case : return false
  }
}

is_special_char :: proc(c: u8) -> bool {
  switch c {
    case 39,40,41,64,91,93,94,96,123,125,126 : return true
    case : return false
  }
}

tokenize :: proc(str : io.Reader) -> [dynamic]string {
  tokens := [dynamic]string{}
  r : bufio.Loadahead_Reader
  buffer := [5]u8{}
  bufio.lookahead_reader_init(&r,str,buffer[:])
  for tmp,error := bufio.lookahead_reader_peek(&r,1);
      len(tmp) != 0 && error == io.Error.None;
      tmp,error = bufio.lookahead_reader_peek(&r,1) {
    switch tmp[0] {
      // White Space
      case 9,10,13,32,44 : error = bufio.lookahead_reader_consume(&r,1)
      // Special Characters {}()'`~^@
      case 39,40,41,64,91,93,94,96,123,125,126 :
        tmp,error = bufio.lookahead_reader_peek(&r,2)
        if error == io.Error.None && tmp[1] == 64 {
          append(&tokens,strings.clone_from(tmp))
          error = bufio.lookahead_reader_consume(&r,2)
        } else {
          append(&tokens,strings.clone_from(tmp[0:1]))
          error = bufio.lookahead_reader_consume(&r,1)
        }
      //strings
      case 34 : token : [dynamic]u8
                append(&token,tmp[0])
                error = bufio.lookahead_reader_consume(&r,1)
                for len(tmp) > 0 && error == io.Error.None && tmp[0] != 34{
                  append(&token,tmp[0])
                  error = bufio.lookahead_reader_consume(&r,1)
                  tmp,error = bufio.lookahead_reader_peek(&r,1)
                }
                if error == io.Error.None && tmp[0] == 34 {
                  append(&token,tmp[0])
                  error = bufio.lookahead_reader_consume(&r,1)
                } 
                append(&tokens,strings.clone_from_bytes(token[:]))
      //comments
      case 59 : for len(tmp) > 0 && error == io.Error.None && tmp[0] != 10 {
                  error = bufio.lookahead_reader_consume(&r,1)
                  tmp,error = bufio.lookahead_reader_peek(&r,1)
                }
                error = bufio.lookahead_reader_consume(&r,1)
      //everything else
      case : token : [dynamic]u8
              for (len(tmp) > 0 && error == io.Error.None && !is_whitespace(tmp[0]) && !is_special_char(tmp[0]) && tmp[0] != 59) {
                append(&token,tmp[0])
                error = bufio.lookahead_reader_consume(&r,1)
                tmp,error = bufio.lookahead_reader_peek(&r,1)
              }
              append(&tokens,strings.clone_from_bytes(token[:])) 
              // error = bufio.lookahead_reader_consume(&r,1)
    }
  }
  return tokens
}

read_form :: proc(reader : ^Reader) -> MalType{
  type : MalType
  if reader_has_next(reader){
    token := reader_peek(reader)
    switch token[0] {
      case 40 : type = read_list(reader)
      case : type = read_atom(reader) 
    }
  }
  return type
}

read_list :: proc(reader : ^Reader) -> MalType {
  list := [dynamic]MalType{}
  token : string
  reader_consume(reader)
  for reader_has_next(reader){
    token := reader_peek(reader)
    if token[0] == 41 {
      reader_consume(reader)
      break
    }
    append(&list,read_form(reader))
  }
  return List{items = list[:]}
}

read_atom :: proc(reader : ^Reader) -> MalType {
  token := reader_consume(reader)
  atom : MalType
  switch token[0] {
    //number
    case 45 : fallthrough
    case 48..=57 :  if value,ok := strconv.parse_int(token); ok{
                      atom = Number{value = value}
                    } else do atom = Symbol{name = token}
    //string
    case 34 : atom = String{value = strings.cut(token,1,len(token) - 2)}
    case : if token == "nil" do atom = Nil{}
           else if token == "false" do atom = False{}
           else if token == "true" do atom = True{}
           else if token[0] == 58  do atom = Keyword{name = strings.cut(token,1)}
           else do atom = Symbol{name = token} 
  }
  return atom
}

read_string :: proc(str : io.Reader) -> MalType {
  tokens := tokenize(str)
  reader := Reader{}
  reader_init(&reader,tokens[:])
  return read_form(&reader)
}
