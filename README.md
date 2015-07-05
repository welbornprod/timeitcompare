timeit-compare
==============

A small bash script that makes it easy to compare python code snippets using
the `timeit` module.

Command Line Help:
------------------
```
Usage:
    timeitcompare -h | -v
    timeitcompare [-e=executable...] [CODE...] [-- ARGS...]

Options:
    CODE              : One or more code snippets to compare.
                        If no snippets are given, input is read from stdin.
                        You can force reading from stdin by passing -.
                        If a file name is given, it will be read and used.
    ARGS              : Extra arguments for timeit.
                        Must be last, and come after the -- separator.
    -e=exe,--exe=exe  : Executable to use. [Default: python3]
                        This flag can be set multiple times.
                        All code snippets will be used once per executable.
    -h,--help         : Show this message and exit.
    -v,--version      : Show version and exit.
```

Usage Examples:
---------------

Example of comparing two code snippets:
```
timeitcompare "[str(c) for c in nums]" "map(str, nums)" -- -s "nums=range(5)"
```

Example of comparing two interpreters with the same snippet:
```
timeitcompare -e=python -e=python3 "map(str, nums)" -- -s "nums=range(5)"
```

Example of comparing two interpreters with two code snippets:
```
timeitcompare -e=python -e=python3 "[str(c) for c in nums]" "map(str, nums)" -- -s "nums=range(5)"
```

Example of output:
```
Using: python -s nums=range(5)
    Timing: [str(c) for c in nums]
        1000000 loops, best of 3: 0.966 usec per loop

    Timing: map(str, nums)
        1000000 loops, best of 3: 0.853 usec per loop


Using: python3 -s nums=range(5)
    Timing: [str(c) for c in nums]
        1000000 loops, best of 3: 1.87 usec per loop

    Timing: map(str, nums)
        1000000 loops, best of 3: 0.27 usec per loop

```

Examples of reading stdin/files:
```
timeitcompare < snippet.py            # snippet.py is read and used.
timeitcompare snippet.py snippet2.py  # both files used as separate snippets.
echo "x=1" | timeitcompare            # stdin is used as a snippet.
timeitcompare                         # stdin will be read and used (at least one line)
```

Example of mixing files, snippets, and stdin.
```
echo "map(str, range(5))" | timeitcompare "(str(c) for c in range(5))" - snippet.py
```
