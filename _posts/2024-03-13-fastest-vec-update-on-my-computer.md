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

#### Constraints and Requirements from Up Above

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
- It must be as fast as possible
- It is expected to operate on large lists of data.

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

### Naive Solution

Rust has a builtin vector type with the methods: `insert` and `remove`. Exactly
what we need.

```rust
fn fast_update(input: &mut Vec<u8>, updates: &[Update]) {
    for update in updates {
        match *updates {
            Update::Remove(idx) => {
                input.remove(index);
            }
            Update::Insert(index, value) => {
                input.insert(index, value)
            }
        }
    }
}
```

Super simple, except it's wrong. This will only work for the very first update.
We need to keep track of 2 more things: how much the indexes have changed, and
if we've already removed that index.

More interesting than it being wrong is that it is extremely slow. `O(n * m)`
to be exact. This is because when you remove and insert, you have to shift
everything else after it over. Even if we got the "correct" answer I would still
consider this solution to be incorrect because it is way to slow. If you'd like
to spend your time waiting on a "correct" solution you can implement it yourself,
but I'd rather spend my time optimizing a problem no one asked me to.

### Big Oh Yeah

Lets make it linear. Start by making a second list, this will be returned
instead of mutating the input. This is an extra nice property to have, that we
will keep up until the end. Then we will take elements from either `input` or
`updates` depending on what the current `update` is. 

```rust
pub fn fast_update(input: &[u8], updates: &[Update]) -> Vec<u8> {
    // calculate the change in the vector size
    let mut v = Vec::new(); // you can also use `with_capacity()`

    let mut updates = updates.iter();
    let mut inputs = input.iter().enumerate();

    let mut update = updates.next();
    let mut next_input = inputs.next();

    // loop until no updates apply to current idx
    loop {
        match (update, next_input) {
            // skip `next_input` if removing at that index
            (Some(Update::Remove(index)), Some((idx, _))) if *index == idx => {
                update = updates.next();
                next_input = inputs.next();
            }
            // insert the value in `index`
            (Some(Update::Insert(index, insert_val)), Some((idx, _))) if *index == idx => {
                v.push(*insert_val);
                update = updates.next();
            }
            // insert the value 
            (_, Some((_, val))) => {
                v.push(*val);
                next_input = inputs.next();
            }
            // when both lists are empty, break
            (None, None) => break,
            // we ignore some edge cases for simplicity
        }
    }

    v
}
```

_You could also do this with the `Peekable` iterator, but I chose this approach
because it seemed more spicy._

This works and it is fast. For an input size of 100,000 and an updates
size of 5,000, we get the following results:

| method | mean speed |
|--------|------------|
| slow   | 	5.2620 ms |
| faster |  206.07 µs |

A very large speed up to say the least. I would argue that while this level of
optimization is not premature for the problem as stated.

### We aren't Done Yet

If this was a basic programming tutorial created by "Big OOP", then I'd say we
are done. Likely I'd make an excuse about how we aren't here for premature
optimization. But that isn't why I'm here!
Lets rebel against useless, over-quoted, misunderstood mantras about optimization.
Fight Big OOP. The point here is to go **supa fast**, not just fast. We
are using Rust, so lets use _use rust_. Don't stop here, but instead push onward
to higher and faster plains of code.
