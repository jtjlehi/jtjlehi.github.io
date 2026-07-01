---
layout: post
title: "A Novel Look at Error Handling in Rust"
tags: ["rust", "rust error handling", "go", "crate ideas", "observations"]
---

[There](https://burntsushi.net/rust-error-handling/) [has](https://dev.to/nathan20/how-to-handle-errors-in-rust-a-comprehensive-guide-1cco) [been](https://medium.com/@Murtza/error-handling-best-practices-in-rust-a-comprehensive-guide-to-building-resilient-applications-46bdf6fa6d9d) [a](https://stevedonovan.github.io/rust-gentle-intro/6-error-handling.html) [lot](https://blog.logrocket.com/error-handling-rust/) said about error handling in rust. There are many different opinions about how to structure your errors, when to use panics, and the role of [proc-macros](https://docs.rs/thiserror/latest/thiserror/) in error handling. Most of the discussion around rust error handling makes the assumption that when an error occurs you either pass the error up to the caller or you try to completely recover and continue on. While this describes many situations, it fails to address all of them. I want to take a different look at error handling and how it can be approached. This is not meant to replace the mainstream miasma of error propogation, it is merely meant to add a new tool in your toolbelt.

## An Overview of the Status Quo

If we have a function that calls function that returns `Result` there a few different ways this could be handled in rust. To illustrate this, lets say we have a function that takes 2 strings, parses them into `u32`s and adds them together. Here are a couple of different ways we could handle failing to parse the string.

It may just panic. When this is the case, it is quite common to explain this in the documentation for the function.

```rust
/// Parse the 2 strings into a `u32`s and add them
///
/// # Panics
///
/// Panics if the provided string can not be parsed
fn add_strs_panic(s1: &str, s2: &str) -> u32 {
    let u1 = s1.parse().expect("s1 should be a valid `u32`");
    let u2 = s2.parse().expect("s2 should be a valid `u32`");
    u1 + u2
}  
```

It may return an `Option`. This approaches will often utilize the combinators provided by the standard library like [`Option::ok`](https://doc.rust-lang.org/std/result/enum.Result.html#method.ok) in conjuction with the question mark operator.

```rust
/// Parse the 2 strings into `u32`s and add the results
///
/// returns `None` if parsing fails
fn add_strs_option(s1: &str, s2: &str) -> Option<u32> {
    let u1 = s1.parse().ok()?;
    let u2 = s2.parse().ok()?;
    Some(u1 + u2)
}
```

It may return an result type. This often involves wrapping the error up in some way.

```rust
enum AddStrsError {
    // variants that wrap it nicely (skipped for brevity)
}
/// parse the 2 strings into `u32`s and add the results
///
/// return an error if parsing fails
fn add_strs_result(s1: &str, s2: &str) -> Result<u32, AddStrsError> {
    let u1 = s1.parse().map_err(/* provide more context for the error */)?;
    let u2 = s2.parse().map_err(/* provide more context for the error */)?;
    Ok(u1 + u2)
}
```

There is even a nice way to handle not failing at all and instead recovering from the failure. A function treat bad inputs as `0` or some other random value.

(As an aside, I think the ability to easily and cleanly _recover from errors_ is one of the main benifits of "errors as values".)

```rust
/// parse the 2 strings into `u32`s and add the results
///
/// if parsing fails, defaults the value to 0
fn add_strs_default(s1: &str, s2: &str) -> u32 {
    // we could use `unwrap_or_default` but I think 0 is more clear here
    let u1 = s1.parse().unwrap_or(0); 
    let u2 = s2.parse().unwrap_or(0);
    u1 + u2
}
```

## The Problem

The last example is somewhat contrived and probably wouldn't make sense for that example, but I have written code that looks somewhat like that code. "Defaulting" code has a problem: the caller of the function has no way of knowing if it was done. It totally reasonable for a function to recover from an error and continue doing work. It is also reasonable for the caller of a function to want to know that something inside the function failed. The problem is the lack of a solution for when both of these things happen together.

This problem, failing but also continuing, is somewhat common. A few (perhaps more realistic) examples of this include:
- Collecting all errors that occur during a specific stage of a compiler.
- Using a default file path if the file path doesn't exist
- Treating a zero in the denominator of a division operator as evaluating to 0[^1]
- Running all of the tests in a test suite even if some of them fail [^2]

## Solution 1: The Go Approach

I think it is quite interesting that the way the [go programming language](https://go.dev/) [handles errors](https://go.dev/blog/error-handling-and-go) doesn't have this problem. For those who aren't familiar I'll provide an extremely brief overview.

`Go`, like rust, uses "errors as values". In go, an error is any type that implements the `Error` interface. Unlike rust, `Go` doesn't really have sum types. So instead of using sum types, a function that can fail returns a tuple with the happy path value and an `error` type like this:

```go
func AddStrsDefault(s1 string, s2 string) (uint64, error) {
	var err error
	i1, err := strconv.ParseUint(s1, 10, 32)
	// note: if both functions return an error, only the second error will be seen
	i2, err := strconv.ParseUint(s2, 10, 32)

	return i1 + i2, err
}
```

Because any pointer in `Go` can be `nil`, if there isn't an error, the returned value is set to `nil`.

This could be a viable option when we encounter the problem in rust. If our computation will always complete but there may be an error as well we could return an optional error too:

```rust
fn add_strs_default(s1: &str, s2: &str) -> (u32, Option<AddStrsError>) {
    let mut ret_err: Option<AddStrsError> = None;

    // we could use `unwrap_or_default` but I think 0 is more clear here
    let u1 = match s1.parse() {
        Ok(val) => val,
        Err(err) => {
            ret_err = Some(/* map the error */);
            0
        }
    }; 
    let u2 = match s2.parse() {
        Ok(val) => val,
        Err(err) => {
            ret_err = Some(/* map the error */);
            0
        }
    }; 
    (u1 + u2, ret_err)
}
```

Then a caller of the function could choose to propagate the error or just use the provided value.

A couple of things to note here:
- It would be trivial to change this to support returning multiple errors.
- This is not as ergonomic as the go code, or any of the variants depicted above. This is mainly because the code is mostly consumed by code focused on error handling. If this function where actually complicated, I could envision a function using this pattern to be somewhat unreadable.
- The type signature doesn't really indicate that the function could fail.

I think this solution works for one off functions that are relatively simple, but if you're code has a lot of functions like this, or the logic in the code is overly complex, I don't think this solves the problem.

## What We Actually Want

In order to come up with a solution, I think it's valuable to enumerate what you want. This can also help identify when more than one solution is merited. For this problem, I want the following things:
- It should be possible to continue working with some sort of default value
- The "happy path" should dominate the logic as much as possible
- The signature of the function should make it clear that failure is possible
- It should be easy to return more than one error
- It should compose with "traditional rust error handling"
- It should compose with itself
- It should still be possible to return early from a function
- It should be as "idiomatic" as possible

## Solution 2: Error Parameter

The first solution I'll propose is what I call an "error parameter". The idea is to pass an parameter to you're fallible function that can collect the errors in a number of different ways. This is especially useful for situations where the errors you're collecting are fairly holistic, in the sense that you want to collect errors from a large portion of your application.

It is very possible to create something to do this with extremely little effort, but I do think there's a place in the ecosystem for a crate like [anyhow](https://docs.rs/anyhow/latest/anyhow/) to make a more comprehensive api to help with this approach.[^3]

Here's what a simple version could look like:

```rust
// You could also create a variant that only holds a specific error.
#[derive(Default)]
struct MultiErrors(Vec<Box<dyn Error>>);

impl MultiErrors {
    /// handle a `Result`, adding any errors internally
    ///
    /// This is very similar to the `Result::ok` function in the standard library
    // A more ergonomic version of this api would probably want to use interior mutability in some form
    fn handle_result<T, E>(&mut self, res: Result<T, E>) -> Option<T>
        where E: Error
    {
        match res {
            Ok(val) => Some(val),
            Err(err) => self.0.push(
                Box::new(err) as Box<dyn Error>
            ),
        }
    }
    /// Check if there are any errors inside here
    fn is_ok(&self) -> bool {
        self.0.is_empty()
    }
    /// Get all the errors encountered
    fn get_errs(&self) -> &[Box<dyn Error>] {
        &self.0
    }
    /// Convert to a `Result`
    fn as_result(&self) -> Result<(), &[Box<dyn Error>]> {
        if self.is_ok() {
            Ok(())
        } else {
            Err(self.get_errs())
        }
    }
}
```

You could use this type like this:

```rust
fn add_strs_result(
    s1: &str,
    s2: &str,
    errs: &mut MultiErrors
) -> u32 {
    let u1 = errs.handle_result(s1.parse()).unwrap_or(0);
    let u2 = errs.handle_result(s2.parse()).unwrap_or(0);
    u1 + u2
}
```

I think this is a pretty good approach. It meets most of the needs originally outlined. It composes well with itself and with "traditional rust error handling". It greatly reduces the amount of code needed for handling individual errors. And it allows for plenty of different use cases. I think that this is a very good solution to the problem.

All that being said, I don't think this approach is perfect. This approach doesn't force you to handle (or at least acknowledge) the failures, It isn't the most "idiomatic" approach in the world, and the return type doesn't communicate that this function can fail (even though the function type as a whole does). There is probably other solutions that pick different tradeoffs[^4]. I especially think it would be interesting to see how one could utilize the unstable [`Try`](https://doc.rust-lang.org/std/ops/trait.Try.html) trait to solve the problem.

## Conclusion

Traditional error handling in Rust is very nice. It is also insufficient for certain types of tasks. Specifically, it doesn't work for cases where you want to continue doing work and also report the error back to the caller. The Go approach to error handling works but doesn't compose with traditional error handling. I think a better alternative is to pass a `MultiErrors` struct into the caller and have that keep track of the errors encountered while running the function. Hopefully this shines some light on an interesting problem related to rust error handling and there can be more discussion about how to handle errors in rust.

# Footnotes

[^1]: I actually think that there are cases where it makes sense to just let this become `NaN`. The biggest reason for being that `NaN` kinda operates like an error path but it doesn't require any branching in your code. Sometimes it's better (faster, clearer, and still correct) to not handle all possible occurances of `NaN`.

[^2]: I do think this can be valuable, and is almost always the correct _default_ but I also think there are cases where one test failing means that another test will always fail and running the second test just creates noise. Often these kinds of test dependencies create a complicated DAG and it makes sense why not all test frameworks (including the default rust testing framework) support this

[^3]: I have plans to make a crate like this, but I also have plans for maybe 10 other projects that are in varying stages of completion. I'm just happy I got a blog post written.

[^4]: For example, if I were to do it in haskell, I'd use a variant of the [`Writer` Monad](https://hackage-content.haskell.org/package/mtl-2.3.2/docs/Control-Monad-Writer-Lazy.html#t:Writer) instead of explicitly passing a parameter. This make it easier to compose individual function calls.
