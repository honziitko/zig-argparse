A simple CLI argument parser in Zig.

# Motivation

I need an argument parser that supports:

  - Positional-bound flags (e.g. `-x` in GCC)
  - Zig 0.15.1

The best one, to my knowledge, is [zig-args](https://github.com/ikskuh/zig-args)
by ikskuh.
However, it does not support either of those features mentioned.

# Features

  - [x] Long options
  - [x] Short options
  - [x] `--` positional directive
  - [x] Integers
  - [x] Strings
  - [x] Choices/modes/enum options
  - [x] Arbitrary stateless types
  - [x] Arbitrary arity
  - [ ] Stateful types (e.g. verbosity in ssh)
  - [ ] Positional-bound arguments

# Documentation

There will be no documentation until this evolves into a mature library.

However, if you so insist, look at the commit history of
[example.zig](example.zig).
