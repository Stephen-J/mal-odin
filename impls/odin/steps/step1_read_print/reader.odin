package main
import "core:fmt"

read_string :: proc() {
  fmt.println("Hello From read string")
  tokenize()
}

tokenize :: proc() {
  fmt.println("Hello from tokenize")
}
