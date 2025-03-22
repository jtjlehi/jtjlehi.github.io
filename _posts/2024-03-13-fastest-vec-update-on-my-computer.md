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

### Source Code

For those interested, [here's the source code](https://github.com/jtjlehi/fast-vec-updates?tab=readme-ov-file).
I used nix to pin the exact version of the nightly compiler I am using.

All of the benchmarks from the `Criterion` library.

I performed all benchmarks on a m1 macbook pro (running asahi linux).

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

### Make it Faster?

What about an iterator?  To start, we need a
struct to store all of the state. I'm opting to store a slice and an index for
each list but you could also store an iterator. I'm also using a borrowing
iterator so our function signature can still take a reference to the slice of
updates. We can then collect that struct in our function body.

```rust
struct UpdateIter<'a> {
    updates: &'a [Update],
    update_idx: usize,
    input: &'a [u8],
    input_idx: usize,
}
impl Iterator for UpdateIter<'_> {
    #[inline]
    fn next(&mut self) -> Option<Self::Item> {
        todo!("")
    }
}
fn fast_update(input: &[u8], updates: &[Udpate]) -> Vec<u8> {
    UpdateIter {
        updates,
        update_idx: 0,
        input,
        input_idx: 0,
    }
    .collect()
}
```

For the body of `next` we want to: return the current value of the input, return
the next input, or skip an input.
Lets start with those first 2, they seem much simpler

```rust
let next_update = self.updates.get(self.update_idx);

match next_update {
    Some(Update::Remove(index)) if *index == self.input_idx => todo!(),
    // insert the value in `index`
    Some(Update::Insert(index, insert_val)) if *index == self.input_idx => {
        update_idx += 1;
        Some(insert_val)
    }
    // insert the value 
    _ => {
        input_idx += 1;
        self.input.get(self.input_idx - 1)
    }
    // we ignore some edge cases for simplicity
}
```

The question remains, how do we skip on removes? The trick there is to skip
all removes before getting to that match statement.

```rust
loop {
    match self.updates.get(self.update_idx) {
        Some(Update::Remove(idx)) if self.input_idx == *idx => {
            self.update_idx += 1;
            self.input_idx += 1;
        }
        Some(Update::Remove(idx)) if self.input_idx > *idx => {
            // idempotent removal
            self.update_idx += 1;
        }
        _ => break,
    }
}
```

But is it fast? No. It was slower. For the same sample size as before, it had a
mean time of `248.40 µs`.

### Splitting it up

What if we try splitting up the updates into 2 parts, performing all of the
inserts and then all of the removes.

First we will need to split the updates list up:

```rust
let (removes, inserts): (Vec<_>, Vec<_>) = updates
    .into_iter()
    // we have to make sure that removes happen at the correct offset
    .scan(0, |num_inserts, update| {
        Some(match update {
            Update::Remove(idx) => Update::Remove(idx + *num_inserts),
            insert @ Update::Insert(_, _) => {
                *num_inserts += 1;
                insert
            }
        })
    })
    .partition(|updates| matches!(updates, Update::Remove(_)))
```

To apply both the inserts and removes, we can loop over the inputs, and either
remove or insert when the index is of the update matches.

for inserts it looks like this:
```rust
let mut output = Vec::with_capacity(input.len() + inserts.len());
let mut inserts = inserts.into_iter();
let mut next_insert = inserts.next();
for (idx, &val) in input.iter().enumerate() {
    while let Some(Update::Insert(insert_idx, insert_val)) = next_insert {
        if insert_idx == idx {
            next_insert = inserts.next();
            output.push(insert_val);
        } else {
            break;
        }
    }
    // we always push the current val
    output.push(val);
}
// we will also need to make sure there aren't any inserts left
```

And it turns out this is even slower than the iterator approach. But that makes
sense when you think about it. We have increased the number of allocations and
conditionals.

### Splitting, but Better

While the idea split is good, the execution is terrible. Lets take a step back
and consider what splitting is trying to acheive. When we apply the updates in
the original loop, we face the problem that we aren't being predictable to the
CPU. Most of what we are doing is moving data from the original input to the
output, but the CPU cannot predict that with so many different branches. The
hope with splitting up `Updates` is to make the operations we are doing more
predictable, but currently we aren't doing that.

The first problem is that we still need to check that we have the correct update
variant. The second is that in every iteration of the loop we have to check if
the update should be applied.

We can solve the first problem by changing the types. Instead of using the
`Update` enum after splitting, we can instead use `usize` for removes and
`(usize, u8)` for inserts.

```rust
let mut removes = Vec::<usize>::with_capacity(updates.len());
let mut inserts = Vec::<(usize, u8)>::with_capacity(updates.len());

for update in updates {
    match *update {
        Update::Remove(idx) => removes.push(idx + inserts.len()),
        Update::Insert(idx, val) => inserts.push((idx, val)),
    }
}
```

For the second one, we should iterate over the updates in the outer loop and
over the input in the inner loop. Or perhaps we can just copy the part of the
input we want to come before the update.

```rust
let mut inserted = Vec::with_capacity(input.len() + inserts.len());
let mut prev_idx = 0;
for (insert_idx, val) in inserts {
    inserted.extend_from_slice(&input[prev_idx..insert_idx]);
    inserted.push(val);
    prev_idx = insert_idx;
}
inserted.extend_from_slice(&input[prev_idx..]);
```

And finally, this approach is faster. In fact it has a mean time of `60.698 µs`
for the same inputs as before.

We can get even more speedups if we remove all of the repeated `Remove` updates
while splitting the updates. This eliminates an extra check in the remove loop and gets
our speed down to `59.209 µs`. (the improvement is bigger when we increase our
input sizes).

| method          | mean speed |
|-----------------|------------|
| slow            |  5.2620 ms |
| faster          |  206.07 µs |
| split           |  60.698 µs |
| removed removes |  59.209 µs |

### Unsafe?

We have quite a few allocations currently, and a lot the the standard library
code we are using is doing checks we don't need them to. My hope was that those
checks could be avoided by the compiler but when I looked that the generated
assembly, it didn't seem that was the case. To get around both of these problems
we'll need to use some `unsafe` rust.

To remove the allocations, we'll start by changing the function signature to also
pass in a buffer that we can use in whatever way we want but in the end will
contain the output.

```rust
fn update_split_new_types_1_2<'a, 'b>(
    input: &'a [u8],
    updates: &'a [Update],
    buffer: &'b mut [MaybeUninit<u8>],
) -> &'b [u8];
 
```

To make working with the buffer safer we'll create a struct for holding slices
of the unitialized buffer. Here `len` tells us how much of the slice is initialized.

```rust
struct PartialInitSlice<'a, T> {
    raw_data: &'a mut [MaybeUninit<T>],
    len: usize,
}
```

We could use a raw pointer as well, but the slice already contains the capacity
and this way the lifetimes are a bit easier.

To create instances of the slice, we need to get slices of the buffer with the
proper length.

```rust
let (this_buffer, buffer) = buffer.split_at_mut(cap * std::mem::size_of::<T>());
```

Now we need to convert `this_buffer` from `[MaybeUnit<u8>]` to `[MaybeUnit<T>]`.
Luckily the standard library has a nice function for doing that:
`core::slice::from_raw_parts_mut`.

```rust
PartialInitSlice {
    raw_data: unsafe {
        core::slice::from_raw_parts_mut(
            this_buffer.as_mut_ptr() as *mut MaybeUninit<T>,
            cap,
        )
    },
    len: 0,
}
```

The question now becomes: is it safe? In order to use this function safely the
docs tell us that we must make sure that the slice is all part of the same
allocation, it is properly aligned, it is non_null, be properly initialized, and
must not be accessed through any other pointer.

The last one is actually the easiest to verify. As long as we don't use
`this_buffer` outside of this struct, and `buffer` lives as long as
`PartialInitSlice`, we are safe. This can be easily acheived by wrapping the
construction in a function.

We can also convince ourselves that it is all one allocation because the slice
has `cap * size_of::<T>` bytes and so does `this_buffer`. If `this_buffer` is
sound, we're good. We can use similar reasoning for the alignment. From what I
can tell, it is safe to promote the alignment up from `u8` as long as there is
enough memory to hold it. The last thing to verify is that all of the memory is
properly initialized. This is the exact reason for using `MaybeUninit`. All
memory is properly initialized for `MaybeUninit`.

Initializing the data structure doesn't get us anything unless we can get it to
work like a vec. In order to do that we provide a couple of methods to the
struct.

```rust
impl<'a, T> PartialInitSlice<'a, T> {
    fn get_slice(self) -> &'a [T];
    fn last(&self) -> Option<&T>;
    unsafe fn push_unchecked(&mut self, el: T);
    unsafe fn append_slice_unchecked(&mut self, slice: &[T]);
}
```
The first 2 provide methods ways to get elements from the slice, according to
`len`. These methods can be safe because one of the gaurentees of the struct is
that `len` is only updated when all values in the array at indexes less then
`len` are initialized. (Sadly this invariant isn't enforced by the compiler,
and it is up to the programmer to create an interface that upholds the invariant.
Ideally I would be able to mark `len` as unsafe, so that even within the module
level code, I still must verify that invariant, and both the functions would
be completely sound).

The other 2 methods are for updating the slice. We mark them as unsafe so the
caller must make sure we don't go outside the buffer. This allows us to take
some of the checks out of the hotpath that it seemed the compiler didn't choose
to take out on it's own.

`push_unchecked` it quite straightforward, we merely write the value to
`self.raw_data[self.len]`, and update `len`. `append_slice_unchecked` is a bit
trickier. What we want to do is pretty much this:

```rust
self.raw_data[self.len..self.len + slice.len()] = slice;
self.len += slice.len();
```

but that approach has a couple of problems. The bigger problem is that
`raw_data` and `slice` have different types (`MaybeUninit<T>` and `T`), meaning
the above code won't even type check. A secondary problem is that the above
approach requires a runtime check that we can make the caller verify instead.
We can solve the second problem by instead using `core::ptr::copy_nonoverlapping`.
The first problem can be solved by casting `slice.ptr()` to `MaybeUninit<T>`. We
can't cast `raw_data` because we _know_ that the slice we are writing to is
unitialized, which is immediate undefined behavior.

```rust
let dst = unsafe { self.raw_data.as_mut_ptr().add(self.len) };
let src = slice.as_ptr() as *const MaybeUninit<T>;

unsafe { core::ptr::copy_nonoverlapping(src, dst, slice.len()) };

self.len += slice.len();
```

This method is only slower if your data is large enough. For the data sizes from
before we actually slowed down, but for `50,000` updates and `1,000,000` elements
We do see a slight improvement

Smaller data set:

| method          | mean speed |
|-----------------|------------|
| slow            |  5.2620 ms |
| faster          |  206.07 µs |
| split           |  60.698 µs |
| removed removes |  59.209 µs |
| unsafe          |  66.435 µs |

Larger data set: (Only the 3 fastest methods for brevity)

| method          | mean speed |
|-----------------|------------|
| split           |  602.39 µs |
| removed removes |  589.36 µs |
| unsafe          |  565.38 µs |

I'm not sure why it is slower for smaller amounts of data and faster with more
data. This approach is also much more consistent. Aside from a few outliers,
This approach has a much stronger clustering of data points, my guess is that
it comes largely from removing the allocations which increase the amount of
non-determinism in the system from run to run. The branch misses could also play
into it, but I don't think it is as big of a deal.

### Conclusion and Other Ideas

This project likely doesn't have many "useful" applications in the real world,
especially with the exact constraints I put on it. In other tests I ran I found
it to be _much_ faster to not provide inserts and removes in the same list. It
would probably be even more advantagous to have them be completely seperate
functions and add a function for updating. Despite that I learned quite a bit
and I got a huge rush everytime I made a speed improvement. I think the findings
are quite interesting. I especially found it interesting that splitting up the
seperation and updates into 2 separate steps made such a big speed up. Hopefully
this will give me a better intuition of what sort of things will yeild actual
speedups. At the very least it has reaffirmed the mantra to benchmark everything.
