package main

import "core:io"
import "core:bufio"
import "core:strings"
import "core:unicode/utf8"
import "core:fmt"
import "core:strconv"

Token_Type :: enum{
  Special,
  String,
  Non_Special,
}

Token :: struct {
  runes : [dynamic]rune,
  type : Token_Type,
  line : int,
  start : int,
  end : int
}

Reader :: struct {
  tokens : [dynamic]Token,
  position : int
}

reader_init :: proc(reader : ^Reader){
  reader.position = 0
}

reader_push :: proc(reader : ^Reader,token : Token){
  append(&reader.tokens,token)
}

reader_peek :: proc(reader : ^Reader) -> Token {
  return reader.tokens[reader.position]
}

reader_has_next :: proc(reader : ^Reader) -> bool {
  return (reader.position + 1) <= len(reader.tokens)
}

reader_has_n :: proc(reader : ^Reader,n : int) -> bool {
  return (reader.position + n) <= len(reader.tokens)
}

reader_consume :: proc(reader : ^Reader) {
  reader.position += 1
}

reader_destroy :: proc(reader : ^Reader){
  delete(reader.tokens)
}


tokenize :: proc(src : io.Stream,reader : ^Reader) {
  lookahead : bufio.Lookahead_Reader
  buffer : [1024]u8
  bufio.lookahead_reader_init(&lookahead,src,buffer[:])
  source_line := 0
  source_pos := 0
  for peek,error := bufio.lookahead_reader_peek(&lookahead,4);
      (error == io.Error.None || error == io.Error.EOF) && len(peek) != 0 ;
      peek,error = bufio.lookahead_reader_peek(&lookahead,4) {
        r,r_size := utf8.decode_rune_in_bytes(peek)
        token : Token
        tokens : [dynamic]Token
        switch r {
          // whitespace
          case '\u0020','\u002C','\u0009' :
            bufio.lookahead_reader_consume(&lookahead,r_size)
          // special characters
          case '\u0027','\u0028','\u0029','\u0040','\u005B','\u005D','\u0060','\u005E','\u007B','\u007D','\u007E':
            append(&token.runes,r)
            token.type = Token_Type.Special
            reader_push(reader,token)
            bufio.lookahead_reader_consume(&lookahead,r_size)
          // strings
          case '\u0022':
            append(&token.runes,r)
            bufio.lookahead_reader_consume(&lookahead,r_size)
            for {
              peek,error = bufio.lookahead_reader_peek(&lookahead,4)
              if (error == io.Error.None || error == io.Error.EOF) && len(peek) != 0 {
                r,r_size = utf8.decode_rune_in_bytes(peek)
                append(&token.runes,r) 
                bufio.lookahead_reader_consume(&lookahead,r_size)
                if (r == '\u0022') do break
                
              } else do break
            }
            token.type = Token_Type.String
            reader_push(reader,token)
          // comments
          case '\u003B':
            for {
              bufio.lookahead_reader_consume(&lookahead,r_size)
              peek,error = bufio.lookahead_reader_peek(&lookahead,4)
              if (error == io.Error.None || error == io.Error.EOF) && len(peek) != 0 {
                r,r_size = utf8.decode_rune_in_bytes(peek)
                bufio.lookahead_reader_consume(&lookahead,r_size)
                if r == '\u000D' do break
              } else do break
            
            } 
          //non-special
          case :
            append(&token.runes,r)
            bufio.lookahead_reader_consume(&lookahead,r_size)
            should_break := false
            for {
              peek,error = bufio.lookahead_reader_peek(&lookahead,4)
              if (error == io.Error.None || error == io.Error.EOF) && len(peek) != 0 {
                r,r_size = utf8.decode_rune_in_bytes(peek)
                switch r {
                  // comments
                  case '\u003B' : fallthrough
                  // whitespace
                  case '\u0020','\u002C','\u0009' : fallthrough
                  // special characters
                  case '\u0027','\u0028','\u0029','\u0040','\u005B','\u005D','\u0060','\u005E','\u007B','\u007D','\u007E':
                    should_break = true
                  case :
                    append(&token.runes,r)
                    bufio.lookahead_reader_consume(&lookahead,r_size)
                }
                if should_break do break 
              } else do break
            }
            token.type = Token_Type.Non_Special
            reader_push(reader,token)
        }
      }

}

read_list :: proc(token_reader : ^Reader) -> List {
  list := List{}
  reader_consume(token_reader)
  for reader_has_next(token_reader){
    token := reader_peek(token_reader)
    if token.runes[0] == '\u0029' {
      reader_consume(token_reader)
      break
    } else {
      form := read_form(token_reader) 
      append(&list.items,form)
    }
   
  }
  return list
}

read_vector :: proc(token_reader : ^Reader) -> Vector {
  vector := Vector{}
  reader_consume(token_reader)
  for reader_has_next(token_reader){
    token := reader_peek(token_reader)
    if token.runes[0] == '\u005D' {
      reader_consume(token_reader)
      break
    } else {
      form := read_form(token_reader) 
      append(&vector.items,form)
    }
   
  }
  return vector
}

read_atom :: proc(token_reader : ^Reader) -> MalType {
  type : MalType
  if reader_has_next(token_reader){
    token := reader_peek(token_reader)
    switch token.runes[0]{
      case '\u0030' ..= '\u0039' :
        val,ok := strconv.parse_f64(utf8.runes_to_string(token.runes[:]))
        type = Number{val = val}
        reader_consume(token_reader)
      case '\u003A' :
        type = Keyword{name = utf8.runes_to_string(token.runes[1:])}
        reader_consume(token_reader)
      case '\u002D' :
        if len(token.runes) > 1 {
          val,ok := strconv.parse_f64(utf8.runes_to_string(token.runes[:]))
          if ok{
            type = Number{val = val}
            reader_consume(token_reader)
            return type
          }
        }
        fallthrough
      case :
        type = Symbol{name = utf8.runes_to_string(token.runes[:])}
        reader_consume(token_reader)
    }
    
  }
  return type
}

read_map :: proc(token_reader : ^Reader) -> Map {
  form := Map{}
  reader_consume(token_reader)
  for reader_has_next(token_reader){
    token := reader_peek(token_reader)
    if token.runes[0] == '\u007D' {
      reader_consume(token_reader)
      break
    } else if reader_has_n(token_reader,2) {
      append(&form.keys,read_form(token_reader))
      append(&form.values,read_form(token_reader))
    } else do panic("Error Reading Map!!!!!")
  }
  return form
}

read_form :: proc(token_reader : ^Reader) -> MalType {
  form : MalType
  if reader_has_next(token_reader) {
    token := reader_peek(token_reader)
    switch token.type {
      case .Non_Special :
        form = read_atom(token_reader)
      case .String :
        form = String{runes = token.runes}
        reader_consume(token_reader)
      case .Special :
        switch token.runes[0] {
          case '\u0028' : form = read_list(token_reader)
          case '\u005B' : form = read_vector(token_reader)
          case '\u007B' : form = read_map(token_reader)
        }
    }
  }
  return form 
}

read_string :: proc(src : string) -> MalType{
  string_reader : strings.Reader
  strings.to_reader(&string_reader,src)
  string_stream := strings.reader_to_stream(&string_reader)
  token_reader : Reader
  reader_init(&token_reader)
  tokenize(string_stream,&token_reader)
  form := read_form(&token_reader)
  return form
}
