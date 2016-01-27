timeit-compare
==============

A small bash script that makes it easy to compare python code snippets using
the `timeit` module.

Command Line Help:
------------------
```
Usage:
    timeitcomp -h | -v
    timeitcomp [-e=executable...] [CODE...] [-- ARGS...]

Options:
    CODE              : One or more code snippets to compare.
                        If no snippets are given, input is read from stdin.
                        You can force reading from stdin by passing -.
                        If a file name is given, it will be read and used.
    ARGS              : Extra arguments for timeit.
                        Must be last, and come after the -- separator.
                        This is where --setup can be passed.
    -e=exe,--exe=exe  : Executable to use. Default: python3
                        This flag can be set multiple times.
                        All code snippets will be used once per executable.
    -h,--help         : Show this message and exit.
    -v,--version      : Show version and exit.
```

Installation:
-------------

Just symlink `timeitcomp.sh` to somewhere in `$PATH`:
```
cd timeitcompare
ln -s "$PWD/timeitcomp.sh" ~/.local/bin/timeitcomp
```

`colr.sh` should be placed in the same directory as `timeitcomp.sh`, no matter
where you place the symlink. The script will continue to work
(with no colors) without `colr.sh` though.


Usage Examples:
---------------

Example of comparing two code snippets:
```
timeitcomp "[str(c) for c in nums]" "map(str, nums)" -- -s "nums=range(5)"
```

Example of comparing two interpreters with the same snippet:
```
timeitcomp -e=python -e=python3 "map(str, nums)" -- -s "nums=range(5)"
```

Example of comparing two interpreters with two code snippets:
```
timeitcomp -e=python -e=python3 "[str(c) for c in nums]" "map(str, nums)" -- -s "nums=range(5)"
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
timeitcomp < snippet.py            # snippet.py is read and used.
timeitcomp snippet.py snippet2.py  # both files used as separate snippets.
echo "x=1" | timeitcomp            # stdin is used as a snippet.
timeitcomp                         # stdin will be read and used (at least one line)
```

Example of mixing files, snippets, and stdin.
```
echo "map(str, range(5))" | timeitcomp "(str(c) for c in range(5))" - snippet.py
```

Notes:
------

Any interpreter that supports calling timeit with `-m timeit` can be used
(`pypy`, `jython`).
