A simple CLI argument parser in Zig.

# Motivation

I need an argument parser that supports:

  - Positional-bound flags (e.g. `-x` in GCC)
  - Zig 0.15.1

The best one, to my knowledge, is [zig-args](https://github.com/ikskuh/zig-args)
by ikskuh.
However, it does not support either of those things mentioned.
