timeit-compare
==============

A small bash script that makes it easy to compare python code snippets using
the `timeit` module. The snippets share the same setup code (when provided),
which reduces the amount of typing needed to compare multiple snippets.

It helps to answer the question "Which of these runs faster on my machine?",
where `timeit` is designed to answer the question "How fast does this run
on my machine?".

Command Line Help:
------------------
```
Usage:
    timeitcomp.sh -h | -v
    timeitcomp.sh [-e=exe...] [-s code...] [CODE...] [options] [-- ARGS...]

Options:
    CODE                  : One or more code snippets to compare.
                            If a file name is given, it will be read.
                            You can force reading from stdin by passing -.
                            Default: stdin
    ARGS                  : Extra arguments for timeit.
                            Must be last, and come after the -- separator.
    -C,--color            : Use colors, even when piping output.
    -e=exe,--exe=exe      : Python interpreter executable to use.
                            This flag can be set multiple times.
                            All code snippets will be used once per
                            executable.
                            Default: python3
    -h,--help             : Show this message and exit.
    -N,--nocolor          : Disable colors.
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
```bash
cd timeitcompare
ln -s "$PWD/timeitcomp.sh" ~/.local/bin/timeitcomp
```

`colr.sh` should be placed in the same directory as `timeitcomp.sh`, no matter
where you place the symlink. The script will continue to work
(with no colors) without `colr.sh` though.


Usage Examples:
---------------

Example of comparing two code snippets:
```bash
timeitcomp -s "nums=range(5)" "[str(c) for c in nums]" "map(str, nums)"
```

Example of comparing two interpreters with the same snippet:
```bash
timeitcomp -e=python -e=python3 -s "nums=range(5)" "map(str, nums)"
```

Example of comparing two interpreters with two code snippets:
```bash
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
```bash
echo "map(str, range(5))" | timeitcomp "(str(c) for c in range(5))" - snippet.py
```

A contrived example to show `timeitcomp`'s colorized output:
```bash
timeitcomp -s "
s = 'test this out'

def with_split(text):
    return ''.join(
        c for word in text.split()
        for c in word
    )

def with_ne(text):
    return ''.join(
        c for c in text
        if c != ' '
    )

def with_replace(text):
    return text.replace(' ', '')
" "with_split(s)" "with_ne(s)" "with_replace(s)" -e=python -e=python3 -o
```

Output:

![TimeitCompare Colorized Output](https://welbornprod.com/static/media/img/timeitcomp-colorized-output_HKXmpn0.png)

Colors are automatically disabled when piping output, but
can be forced on or off with `--color` and `--nocolor`.

Notes:
------

Any interpreter that supports calling timeit with `-m timeit` can be used
(`pypy`, `jython`).
