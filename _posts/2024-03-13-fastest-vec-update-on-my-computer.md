## Fastest Vec Update on My Computer

"Premature optimization is the root of all evil." At least that is what 'big java'
wants you to think. But if I wasn't worried about optimizations I'd be using 
linked lists in Haskell. I use rust because I want speed. If you are here for
speed, then keep reading. In this post you'll find a detailed account of how I
created a problem, solved the problem, and then optimized the solution way to
much.

### The Problem

The original problem was wanting to find a good problem (yes I see the irony) to
build a better intuition for Data Oriented Programming. Instead of looking up
good problems, or following a tutorial I thought that updating a list really
fast sounded fun. It is doubtful that anyone will ever use this exact interface
to solve this exact problem, but hopefully it is still a fun little exercise for
you.

### The Problem, Actually

In general we want a function that takes in 2 lists, `&[u8]` and `&[Update]`,
and applies each update to the list in order. The "updated" list can either be
a new list or the existing list.

Updates come in 2 forms `Remove(usize)` and `Insert(usize, u8)`. We don't need
a change variant because `Remove(i)` combined with `Insert(i, x)` is the same as
`Change(i, x)`.

```rust
enum Update {
    Remove(usize),
    Insert(usize, u8),
}
```

#### Constraints

Any good problem has constraints. These are the constraints given to us from on
high, or at least the ones I chose to give myself.
- the updates list must be sorted
  - `Insert(i, x) < Remove(i) < Insert(i + 1, y)`
- Inserts must be applied in order
  - so `[Insert(3, 4), Insert(3, 5)]` is essentially equivilant to `Insert(3, [4, 5])`
- Removes are idempotent
- You cannot remove or insert outside the list
- Inserts are applied before their index
- All updates are applied to the indices of the initial list

#### Sudo Example

We want it to work like this

```rust
let initial_values = [1, 2, 2, 3, 7];
let updates = [
  Insert(0, 0_u8),
  Remove(1),
  Insert(4, 4_u8),
  Insert(4, 5_u8),
  Remove(4)
];
// output becomes:
// [0, 1, 2, 3, 4, 5]
```

