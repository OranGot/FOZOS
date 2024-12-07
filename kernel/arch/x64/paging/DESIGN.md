# Design of FOZOS allocators for x64 arch
  written in december 2024 by OranGot
## Allocating a physical page
  API will expose functions such as:
  1. fn await_for_page(address: u64, time: u64)TimedAllocationError!void
    Will pause execution of a program untill a certain physical address is aquired or time out
    in case of time out return error.
  2. fn allocate_pages(count: u32)AllocationError!u64
    Will allocate a number of consequitive pages specified in count if it fails will return
    AllocationError
## Freeing a physical page
  API will expose functions such as
  1. fn free_pages(address: u64, count: u32)FreeError!void
    Will free a number of consequitive pages
## Physical memory manager design:
  Physical pages would be kept in a linked list such as
```
const list_entry_type = enum(u8){
    FREE = 0,
    RESERVED = 1,
    NO_FREE_RESERVED = 2,
    OCCUPIED = 3,
};
```
NO_FREE_RESERVED areas include kernel's, AHCI and other memory.
```
const list_entry = extern struct{
  base: u64,
  high: u64,
  type: list_entry_type,
  next: *list_entry = null,
};
```
```
const header_page = extern struct{
  next: *header_page = null,
  table: [240]list_entry,
  avl: u8 = 0,
};
```
Header page is the primary element of the linked list, tertiary
### How this is kept
first a single page is allocated. Single page can keep up to 240 entries for this table
this would usually be enough however there will be a way to allocate more entries in case your physical memory
is very fragmented.
### Algorithm for allocating physical memory
first allocator will set up it's service pages.
-> It will read limine's memory map and map everything from there which isn't free or
reclaimable as NO_FREE_RESERVED, otherwise free
-> upon calling any of the allocating functions manager will:
  1. Go to next entry
  2. if entry == out_of_bounds: goto next header_page
  3. if entry.type != FREE goto 1 &
  4. allocate memory
  5. if not enough space & bestfit == 1: set entry type as OCCUPIED goto 1
  6. if page to the left or right reserved block. Append to that block and remove from current block
-> upon calling any of the freeing functions manager will:
  1. go over each block and check if target address is included.
  2. When found check if the block is RESERVED otherwise return DoubleFree error
  3. if target_page doesn't isn't touching the borders of a block split the block into 2
