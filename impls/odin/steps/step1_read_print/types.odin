package main

MalType :: union {
  String,
  Number,
  Map,
  Vector,
  List,
  Symbol,
  Keyword,
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
