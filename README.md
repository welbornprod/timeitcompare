timeit-compare
==============

A small bash script that makes it easy to compare python code snippets using
the `timeit` module.

Command Line Help:
------------------
```
Usage:
    timeitcomp.sh -h | -v
    timeitcomp.sh [-e=executable...] [-o] [-s code...] [CODE...] [-- ARGS...]

Options:
    CODE                  : One or more code snippets to compare.
                            If a file name is given, it will be read.
                            You can force reading from stdin by passing -.
                            Default: stdin
    ARGS                  : Extra arguments for timeit.
                            Must be last, and come after the -- separator.
    -e=exe,--exe=exe      : Executable to use. This flag can be set
                            multiple times. All code snippets will be used
                            once per executable.
                            Default: python3
    -h,--help             : Show this message and exit.
    -o,--overhead         : Account for some of the overhead of using
                            timeit to run these snippets.
                            Times the execution of a simple 'pass'
                            statement for each executable, and subtracts
                            that from each snippet's run time.
    -s code,--setup code  : Setup code for timeit (same as timeit -s).
                            Can be used multiple times.
                            This can also be a file name to read setup
                            code from.
    -v,--version          : Show version and exit.
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
timeitcomp -s "nums=range(5)" "[str(c) for c in nums]" "map(str, nums)"
```

Example of comparing two interpreters with the same snippet:
```
timeitcomp -e=python -e=python3 -s "nums=range(5)" "map(str, nums)"
```

Example of comparing two interpreters with two code snippets:
```
timeitcomp -e=python -e=python3 -s "nums=range(5)" "[str(c) for c in nums]" "map(str, nums)"
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
timeitcomp < snippet.py              # snippet.py is read and used.
timeitcomp -s setup.py < snippet.py  # setup code is read from setup.py, snippet.py is timed.
timeitcomp snippet.py snippet2.py    # both files used as separate snippets.
echo "x=1" | timeitcomp              # stdin is used as a snippet.
timeitcomp                           # stdin will be read and used (at least one line)
```

Example of mixing files, snippets, and stdin.
```
echo "map(str, range(5))" | timeitcomp "(str(c) for c in range(5))" - snippet.py
```

Notes:
------

Any interpreter that supports calling timeit with `-m timeit` can be used
(`pypy`, `jython`).
