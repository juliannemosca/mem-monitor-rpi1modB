SECTIONS {
  .init 0x8000 : { *(.init) }
  .data :
    {
    *(.data)
    *.c.o(*)
    }
  .text :
    {
    *.c.o(.text)
    *(.text)
    }
}
