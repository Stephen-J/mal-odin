package main
import "core:testing"
import "core:strings"
import "core:fmt"

@(test)
tokenize_test :: proc(t : ^testing.T) {
  src : strings.Reader
  tokens : [dynamic]string

  tokens = tokenize(strings.to_reader(&src,"     "))
  testing.expect_value(t,len(tokens),0)

  tokens = tokenize(strings.to_reader(&src,"{} ( ) ' ` ~ ^ @ ~@"))
  testing.expect_value(t,len(tokens),10)
  testing.expect_value(t,tokens[0],"{")
  testing.expect_value(t,tokens[1],"}")
  testing.expect_value(t,tokens[2],"(")
  testing.expect_value(t,tokens[3],")")
  testing.expect_value(t,tokens[4],"'")
  testing.expect_value(t,tokens[5],"`")
  testing.expect_value(t,tokens[6],"~")
  testing.expect_value(t,tokens[7],"^")
  testing.expect_value(t,tokens[8],"@")
  testing.expect_value(t,tokens[9],"~@")

  tokens = tokenize(strings.to_reader(&src,"asymbol anothersymbol yetanothersymbol"))
  testing.expect_value(t,len(tokens),3)
  testing.expect_value(t,tokens[0],"asymbol")
  testing.expect_value(t,tokens[1],"anothersymbol")
  testing.expect_value(t,tokens[2],"yetanothersymbol")
  
  tokens = tokenize(strings.to_reader(&src,"123 456 -1 789"))
  testing.expect_value(t,len(tokens),4)
  testing.expect_value(t,tokens[0],"123")
  testing.expect_value(t,tokens[1],"456")
  testing.expect_value(t,tokens[2],"-1")
  testing.expect_value(t,tokens[3],"789")

  builder := strings.builder_make()
  strings.write_rune(&builder,'"')
  strings.write_string(&builder,"a string")
  strings.write_rune(&builder,'"')
  strings.write_rune(&builder,'"')
  strings.write_string(&builder,"another string")
  strings.write_rune(&builder,'"')
  strings.write_rune(&builder,'"')
  strings.write_string(&builder,"yet another string")
  strings.write_rune(&builder,'"')
  tokens = tokenize(strings.to_reader(&src,strings.to_string(builder)))
  testing.expect_value(t,len(tokens),3)

  tokens = tokenize(strings.to_reader(&src,";"))
  testing.expect_value(t,len(tokens),0)
  tokens = tokenize(strings.to_reader(&src,"asymbol ;"))
  testing.expect_value(t,len(tokens),1)
  tokens = tokenize(strings.to_reader(&src,"asymbol ; with a comment")) 
  testing.expect_value(t,len(tokens),1)
  // taken from the mal test
  tokens = tokenize(strings.to_reader(&src,"1; &()*+,-./:;<=>?@[]^_{|}~")) 
  testing.expect_value(t,len(tokens),1)

  tokens = tokenize(strings.to_reader(&src,"(+ 1 2 3)"))
  testing.expect_value(t,len(tokens),6)

  tokens = tokenize(strings.to_reader(&src,"[1 2 3]"))
  testing.expect_value(t,len(tokens),5)

  tokens = tokenize(strings.to_reader(&src,"{:a 100 :b 200}"))
  testing.expect_value(t,len(tokens),6) 
}

@test
read_atom_test :: proc(t : ^testing.T) {
  reader : Reader
  form : MalType
  tokens : []string

  tokens = []string{"123"}
  reader_init(&reader,tokens)
  form = read_atom(&reader)
  if num,ok := form.(Number); !ok || num.value != 123 do testing.fail(t)

  tokens = []string{"-123"}
  reader_init(&reader,tokens)
  form = read_atom(&reader)
  if num,ok := form.(Number); !ok || num.value != -123 do testing.fail(t)     

  tokens = []string{"asymbol"}
  reader_init(&reader,tokens)
  form = read_atom(&reader)
  if symbol,ok := form.(Symbol); !ok || symbol.name != "asymbol" do testing.fail(t)

  tokens = []string{"\"a string\""}
  reader_init(&reader,tokens)
  form = read_atom(&reader)
  if str,ok := form.(String); !ok || str.value != "a string" do testing.fail(t)
  
  tokens = []string{"nil"}
  reader_init(&reader,tokens)
  form = read_atom(&reader)
  if nil,ok := form.(Nil); !ok do testing.fail(t)

  tokens = []string{"true"}
  reader_init(&reader,tokens)
  form = read_atom(&reader)
  if true_type,ok := form.(True); !ok do testing.fail(t)

  tokens = []string{"false"}
  reader_init(&reader,tokens)
  form = read_atom(&reader)
  if false_type,ok := form.(False); !ok do testing.fail(t)

  tokens = []string{":keyword"}
  reader_init(&reader,tokens)
  form = read_atom(&reader)
  if keyword,ok := form.(Keyword); !ok || keyword.name != "keyword"  do testing.fail(t)
}

@(test)
read_form_test :: proc(t : ^testing.T) {
  reader : Reader
  form : MalType
  tokens : []string
  
  tokens = []string{"123"}
  reader_init(&reader,tokens)
  form = read_form(&reader)
  if num,ok := form.(Number); !ok do testing.fail(t)
}
