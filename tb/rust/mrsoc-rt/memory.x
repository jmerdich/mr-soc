MEMORY
{
  IO    : ORIGIN = 0x00000000, LENGTH = 16K
  RAM   : ORIGIN = 0x00010000, LENGTH = 16K
  FLASH : ORIGIN = 0x00020000, LENGTH = 32K
}

REGION_ALIAS("REGION_IO", IO);
REGION_ALIAS("REGION_TEXT", FLASH);
REGION_ALIAS("REGION_RODATA", FLASH);
REGION_ALIAS("REGION_DATA", RAM);
REGION_ALIAS("REGION_BSS", RAM);
REGION_ALIAS("REGION_HEAP", RAM);
REGION_ALIAS("REGION_STACK", RAM);


SECTIONS
{
    .section_io : ALIGN(0x1000)
    {
        /* space efficient? Nah. But well-known addresses are nice. */
        .io_start = .;
        . += 4;
        . = ALIGN(0x1000);
        tohost = .;
        . += 4;
        . = ALIGN(0x1000);
        hosthalt = .;
        . += 4;
        . = ALIGN(0x1000);
        .io_end = .;
    } > REGION_IO
}
