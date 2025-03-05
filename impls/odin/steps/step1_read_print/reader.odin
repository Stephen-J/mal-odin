package main

import "core:io"
import "core:bufio"
import "core:strings"
import "core:unicode/utf8"
import "core:fmt"
import "core:strconv"
import "core:mem"

Token_Type :: enum{
  Special,
  String,
  Non_Special,
}

Token :: struct {
  runes : [dynamic]rune,
  type : Token_Type,
}

token_destroy :: proc(token : ^Token){
  delete(token.runes)
}


Token_Not_Matched :: struct {
  started : rune,
  missing : rune,
}

Error :: union {
  Token_Not_Matched
}

Reader :: struct {
  tokens : [dynamic]Token,
  position : int
}

reader_init :: proc(reader : ^Reader){
  reader.position = 0
}

reader_destroy :: proc(reader : ^Reader){ 
  for &token in reader.tokens do token_destroy(&token)
  delete(reader.tokens)
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

tokenize :: proc(src : io.Stream,reader : ^Reader) {
  lookahead : bufio.Lookahead_Reader
  buffer : [1024]u8
  bufio.lookahead_reader_init(&lookahead,src,buffer[:])
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
            bufio.lookahead_reader_consume(&lookahead,r_size)
            peek,error = bufio.lookahead_reader_peek(&lookahead,4)
            if (error == io.Error.None || error == io.Error.EOF) && len(peek) != 0 && r == '\u007E'{
              r,r_size = utf8.decode_rune_in_bytes(peek)
              if r == '\u0040' {
                append(&token.runes,r)
                bufio.lookahead_reader_consume(&lookahead,r_size)
              }
            }
            token.type = Token_Type.Special
            reader_push(reader,token)
            
          // strings
          case '\u0022':
            append(&token.runes,r)
            bufio.lookahead_reader_consume(&lookahead,r_size)
            for {
              peek,error = bufio.lookahead_reader_peek(&lookahead,4)
              if (error == io.Error.None || error == io.Error.EOF) && len(peek) != 0 {
                r,r_size = utf8.decode_rune_in_bytes(peek)
                if r == '\u005C' {
                  append(&token.runes,r)
                  bufio.lookahead_reader_consume(&lookahead,r_size)
                  peek,error = bufio.lookahead_reader_peek(&lookahead,4)
                  if (error == io.Error.None || error == io.Error.EOF) && len(peek) != 0 {
                    r,r_size = utf8.decode_rune_in_bytes(peek)
                    append(&token.runes,r)
                    bufio.lookahead_reader_consume(&lookahead,r_size)
                  }
                } else if (r == '\u0022') {
                  append(&token.runes,r)
                  bufio.lookahead_reader_consume(&lookahead,r_size)
                  break
                }
                else {
                  append(&token.runes,r)
                  bufio.lookahead_reader_consume(&lookahead,r_size)
                }  
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

read_list :: proc(token_reader : ^Reader) -> (valid_list : List,err : Error) {
  list := List{}
  closing_found := false
  reader_consume(token_reader)
  for reader_has_next(token_reader){
    token := reader_peek(token_reader)
    if token.runes[0] == '\u0029' {
      closing_found = true
      reader_consume(token_reader)
      break
    } else {
      form := read_form(token_reader) or_return 
      append(&list.items,form)
    }
   
  }
  if closing_found {
    return list,nil
  } else { 
    type_destroy(list)
    return list,Token_Not_Matched{started = '(',missing = ')'}
  }
}

read_vector :: proc(token_reader : ^Reader) -> (valid_vector : Vector,err : Error) {
  vector := Vector{}
  closing_found := false
  reader_consume(token_reader)
  for reader_has_next(token_reader){
    token := reader_peek(token_reader)
    if token.runes[0] == '\u005D' {
      reader_consume(token_reader)
      closing_found = true
      break
    } else {
      form := read_form(token_reader) or_return 
      append(&vector.items,form)
    } 
  }
  if closing_found {
    return vector,nil
  } else {
    type_destroy(vector)
    return vector,Token_Not_Matched{started = '[',missing = ']'}
  }
}

read_atom :: proc(token_reader : ^Reader) -> MalType {
  type : MalType
  if reader_has_next(token_reader){
    token := reader_peek(token_reader)
    switch token.runes[0]{
      // numbers
      case '\u0030' ..= '\u0039' :
        n := utf8.runes_to_string(token.runes[:])
        defer delete(n)
        val,ok := strconv.parse_f64(n)
        type = Number{val = val}
        reader_consume(token_reader)
      // keyword
      case '\u003A' :
        type = Keyword{name = utf8.runes_to_string(token.runes[1:])}
        reader_consume(token_reader)
      // numbers with a  -
      case '\u002D' :
        if len(token.runes) > 1 {
          n := utf8.runes_to_string(token.runes[:])
          defer delete(n)
          val,ok := strconv.parse_f64(n)
          if ok{
            type = Number{val = val}
            reader_consume(token_reader)
            return type
          }
        }
        fallthrough
      case :
        s := utf8.runes_to_string(token.runes[:])
        if s == "true" {
          delete(s)
          type = True{}
        } else if s == "false" {
          delete(s)
          type = False{}
        } else if s == "nil" {
          delete(s)
          type = Nil{}
        } else {
          type = Symbol{name = s}
        }
        reader_consume(token_reader)
    }
    
  }
  return type
}

read_map :: proc(token_reader : ^Reader) -> (valid_map : Map,err : Error) {
  form := Map{}
  closing_found := false
  reader_consume(token_reader)
  for reader_has_next(token_reader){
    token := reader_peek(token_reader)
    if token.runes[0] == '\u007D' {
      closing_found = true
      reader_consume(token_reader)
      break
    } else if reader_has_n(token_reader,2) {
      member_form := read_form(token_reader) or_return 
      append(&form.keys,member_form)
      member_form = read_form(token_reader) or_return
      append(&form.values,member_form)
    }
  } 
  if closing_found {
    return form,nil
  } else {
    type_destroy(form)
    return form,Token_Not_Matched{started = '{',missing = '}'}
  }
}

apply_quote :: proc(token_reader : ^Reader) -> (list : List,err : Error) {
  quote_list := List{}
  reader_consume(token_reader)
  if reader_has_next(token_reader) {
    append(&quote_list.items,Symbol{name = fmt.aprint("quote")})
    form := read_form(token_reader) or_return
    append(&quote_list.items,form)
  }
  return quote_list,nil
}

apply_quasiquote :: proc(token_reader : ^Reader) -> (type : MalType,err : Error) {
  list := List{}
  reader_consume(token_reader)
  if reader_has_next(token_reader) {
    append(&list.items,Symbol{name = fmt.aprint("quasiquote")})
    form := read_form(token_reader) or_return
    append(&list.items,form)
  }
  return list,nil
}

apply_unquote :: proc(token_reader : ^Reader) -> (type : MalType,err : Error) {
  list := List{}
  reader_consume(token_reader)
  if reader_has_next(token_reader) {
    append(&list.items,Symbol{name = fmt.aprint("unquote")})
    form := read_form(token_reader) or_return
    append(&list.items,form)
  }
  return list,nil
}

apply_deref :: proc(token_reader : ^Reader) -> (type : MalType,err : Error) {
  list := List{}
  reader_consume(token_reader)
  if reader_has_next(token_reader) {
    append(&list.items,Symbol{name = fmt.aprint("deref")})
    form := read_form(token_reader) or_return
    append(&list.items,form)
  }
  return list,nil
}

apply_metadata :: proc(token_reader : ^Reader) -> (valid_list : List,err : Error) {
  with_meta := List{}
  reader_consume(token_reader)
  if reader_has_next(token_reader) {
    metadata := read_form(token_reader) or_return
    if reader_has_next(token_reader){
      form := read_form(token_reader) or_return
      append(&with_meta.items,Symbol{name = fmt.aprint("with-meta")})
      append(&with_meta.items,form)
      append(&with_meta.items,metadata)
    }
  }
  return with_meta,nil
}

apply_unquote_splice :: proc(token_reader : ^Reader) -> (valid_list : List,err : Error) {
  unquote_splice := List{}
  reader_consume(token_reader)
  if reader_has_next(token_reader) {
    append(&unquote_splice.items,Symbol{name = fmt.aprint("splice-unquote")})
    form := read_form(token_reader) or_return 
    append(&unquote_splice.items,form)
  }
  return unquote_splice,nil
}

unescape_runes :: proc(runes : []rune) -> ([dynamic]rune,Error) {
  unescaped := [dynamic]rune{}
  escape := false
  quote_count := 0
  for r in runes { delim: u8
    if escape {
      switch r {
        case '\u006E' : append(&unescaped,'\u000A')
        case '\u0022' : append(&unescaped,r)
        case '\u005C' : append(&unescaped,r)
      }
      escape = false
    }else if r == '\u005C' do escape = true
    else if r == '\u0022' do quote_count += 1
    else do append(&unescaped,r)
  }
  if quote_count == 2 do return unescaped,nil
    else do return nil,Token_Not_Matched{started = '"',missing = '"'} 
}

escape_runes :: proc(runes : []rune) -> [dynamic]rune {
  escaped := [dynamic]rune{}
  for r in runes {
    switch r {
      case '\u000A' : append(&escaped,'\u005C')
                      append(&escaped,'\u006E')
      case '\u0022' : append(&escaped,'\u005C')
                      append(&escaped,'\u0022')
      case '\u005C' : append(&escaped,'\u005C')
                      append(&escaped,'\u005C')
      case : append(&escaped,r)
    }
  }
  return escaped
}

read_string_form :: proc(token_reader : ^Reader) -> (valid_string : String,err : Error) {
  s : String
  token := reader_peek(token_reader) 
  unescaped := unescape_runes(token.runes[:]) or_return
  s = String{runes = unescaped}
  reader_consume(token_reader)
  return s,nil
}

read_form :: proc(token_reader : ^Reader) -> (type : MalType,err: Error) {
  form : MalType
  if reader_has_next(token_reader) {
    token := reader_peek(token_reader)
    switch token.type {
      case .Non_Special :
        form = read_atom(token_reader)
      case .String :
        form = read_string_form(token_reader) or_return
      case .Special :
        switch token.runes[0] {
          case '\u0028' : form = read_list(token_reader) or_return
          case '\u005B' : form = read_vector(token_reader) or_return
          case '\u007B' : form = read_map(token_reader) or_return
          //reader macros
          case '\u0027' : form = apply_quote(token_reader) or_return
          case '\u0040' : form = apply_deref(token_reader) or_return
          case '\u005E' : form = apply_metadata(token_reader) or_return
          case '\u0060' : form = apply_quasiquote(token_reader) or_return
          case '\u007E' :
            if len(&token.runes) == 2 {
              form =  apply_unquote_splice(token_reader) or_return
            } else do form = apply_unquote(token_reader) or_return
        }
    }
  }
  return form,nil
}

read_string :: proc(src : string) -> (valid_forms : [dynamic]MalType,err : Error){
  forms := [dynamic]MalType{}
  string_reader : strings.Reader
  strings.to_reader(&string_reader,src)
  string_stream := strings.reader_to_stream(&string_reader)
  token_reader : Reader
  defer reader_destroy(&token_reader)
  reader_init(&token_reader)
  tokenize(string_stream,&token_reader)
  for reader_has_next(&token_reader) {
    form,err := read_form(&token_reader)
    if err != nil {
      for form in forms do type_destroy(form)
      delete(forms)
      return [dynamic]MalType{},err
    }else do append(&forms,form)
  }
  return forms,nil
}
