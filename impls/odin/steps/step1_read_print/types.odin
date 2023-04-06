package main

Symbol :: struct{name : string}
Keyword :: struct{name : string}
String :: struct{value : string}
Number :: struct{value : int}
List :: struct{items : []MalType}
Nil :: struct{}
True :: struct{}
False :: struct{}

MalType :: union{
  Symbol,
  String,
  Number,
  List,
  Keyword,
  Nil,True,False}
