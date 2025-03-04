package main
import "core:fmt"

MalType :: union {
  String,
  Number,
  Map,
  Vector,
  List,
  Symbol,
  Keyword,
  Nil,
  True,
  False,
}

String :: struct {
  runes : [dynamic]rune
}

Number :: struct {
  val : f64
}

Map :: struct {
  keys : [dynamic]MalType,
  values : [dynamic]MalType,
}

Vector :: struct {
  items : [dynamic]MalType
}

List :: struct {
  items : [dynamic]MalType
}

Symbol :: struct {
  name : string
}

Keyword :: struct {
  name : string
}

Nil :: struct {}
True :: struct {}
False :: struct {}


type_destroy :: proc(mal_type : MalType){
  switch t in mal_type{
    case String :
      delete(t.runes)
    case Number :
    case Map :
      for key in t.keys do type_destroy(key)
      for value in t.values do type_destroy(value)
      delete(t.keys)
      delete(t.values)
    case Vector :
      for form in t.items do type_destroy(form)
      delete(t.items)     
    case List :
      for form in t.items do type_destroy(form)
      delete(t.items)
    case Symbol :
      delete(t.name)
    case Keyword :
      delete(t.name)
    case Nil :
    case True :
    case False :
  }
}
