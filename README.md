# Vim-UTest

Vim-UTest is a plugin to unit-test Vimscript code.  It has also mocking support.
It can be run from within Vim/Neovim as well as from the command line.

![tests](https://img.shields.io/github/actions/workflow/status/cdelledonne/vim-utest/test.yaml?label=tests)
![language](https://img.shields.io/github/languages/top/cdelledonne/vim-utest)
![version](https://img.shields.io/github/v/tag/cdelledonne/vim-utest?label=version&sort=semver)
![license](https://img.shields.io/github/license/cdelledonne/vim-utest)

![screenshot][screenshot]

**Features**

* Test cases are simply written in Vimscript
* Support for test fixtures with optional set-up and tear-down
* Support for mocking of dependencies
* Can be run from within Vim/Neovim as well as from the command line
* Autocompletion for unit test names (when used from within Vim/Neovim)
* Quickfix list population with test errors (when used from within Vim/Neovim)
* Written in Vimscript

**Related projects**

Here's a list of related projects, some of which Vim-UTest draws inspiration
from: [vim-testify][vim-testify], [vim-UT][vim-UT], [vader.vim][vader.vim],
[vroom][vroom], [vim-vspec][vim-vspec], [vim-themis][vim-themis].

<!--=========================================================================-->

## When to use

Vim-UTest lets you test Vimscript functions.  It is not designed to test user
keystrokes and buffer output.  As such, Vim-UTest works best if the units of
code under test are Vimscript functions that simply process their input
arguments and return Vimscript expressions.  This means that actions like
writing to a buffer and triggering autocommands cannot be tested natively.

A Vimscript project is more suited to be tested with Vim-UTest if
functionalities like writing to buffer, triggering autocommands, etc. are
confined to an abstraction layer at the edge of the project's software
architecture.  The abstraction layer can then be mocked when testing units that
depend on it.  And yes, Vim-UTest supports mocking (see [Writing
mocks](#writing-mocks).

<!--=========================================================================-->

## Installation

Use a package manager like [vim-plug][vim-plug]:

```vim
Plug 'cdelledonne/vim-utest'
```

or Vim's native package manager:

```sh
mkdir -p ~/.vim/pack/plug/start
cd ~/.vim/pack/plug/start
git clone https://github.com/cdelledonne/vim-utest.git
```

<!--=========================================================================-->

## Usage

To use Vim-UTest, you first define some unit tests. Then you just run the
`:UTest` command and observe your tests' results. A quick guide follows.

### Writing unit tests

You can distribute your tests over as many test files as you need, which you can
for instance store in a `test/` directory at the root of your project. The name
and path of this directory are for you to choose.

Start by creating a test fixture. The fixture will then be used to define unit
tests and the optional `SetUp()` and `TearDown()` functions.

```vim
let s:fixture = utest#NewFixture()
```

If desired, define `SetUp()` as a dictionary function of the test fixture. This
function will be run before each unit test, and the unit test will only be run
if this function succeeds.

```vim
function! s:fixture.SetUp() abort
    let self.component = myplugin#component#Get()
endfunction
```

If desired, define `TearDown()` as a dictionary function of the test fixture.
This function will be run after each unit test, regardless of the outcome of the
test, but only if `SetUp()` succeeds.

```vim
function! s:fixture.TearDown() abort
    call self.component.CleanUp()
endfunction
```

Finally, write your unit tests as dictionary functions of the test fixture. Make
use of the [assertion and expectation functions](#functions) provided by
Vim-UTest to test your code.

```vim
function! s:fixture.TestSimpleOk() abort
    let result = self.component.ComputeResult(1, 2)
    call utest#ExpectEqual(result, 3)
endfunction
```

That's it, you're done writing unit tests. Or not — if your component under test
depends on other components that you don't want to trigger, but you still want
to check that your component under test issues the appropriate calls to its
dependencies, then it's time to write a mock!

### Writing mocks

TODO: write this section

Write mock, same file as fixture...

### Commands

When you're done writing unit tests and mocks, you just run the `:UTest`
command.  Run `:help utest-commands` for full documentation.

### Functions

TODO: general functions

TODO: assertion and expectation functions

### Events

Vim-UTest provides a set of custom events to trigger further actions.  Run
`:help utest-events` for some examples.

| Event                     | Description                           |
|:--------------------------|:--------------------------------------|
| `User UTestTestSucceeded` | Triggered after a successful test run |
| `User UTestTestFailed`    | Triggered after a failed test run     |
| `User UTestTestAborted`   | Triggered after a test was aborted    |

### Quickfix list

After each test run, Vim-UTest populates a quickfix list to speed up the
workflow.  Upon an unsuccessful test run, just use the standard quickfix
commands to open the list of errors (e.g. `:copen`) and jump between errors
(e.g. `:cfirst`, `:cnext`).

### Running tests from the command line

For Neovim, just run the `:UTest` command in headless mode (`--headless`):

```sh
nvim --headless -c 'UTest'
```

For Vim, run the `:UTest` command in silent mode (`-e` and `-s`), with the
`'nocompatible'` option (`-N`), optionally disabling swap files (`-n`) and
explicitly loading the user configuration file (`-u`) because silent mode skips
loading this file by default.

```sh
vim -es -N -n -u ~/.vim/vimrc -c 'UTest'
```

Be aware that if you want to echo messages in silent mode (Vim), you need to
use `:verbose echo` instead of just `:echo` for them to be displayed.

<!--=========================================================================-->

## Configuration

Vim-UTest has sensible defaults.  Run `:help utest-configuration` for full
documentation on all the configuration options.  A list of default values
follows.

| Options                       | Default            |
|:------------------------------|:-------------------|
| `g:utest_default_test_dir`    | `'test'`           |
| `g:utest_window_size`         | `15`               |
| `g:utest_window_position`     | `'botright'`       |
| `g:utest_focus`               | `v:false`          |
| `g:utest_focus_on_completion` | `v:false`          |
| `g:utest_focus_on_error`      | `v:true`           |
| `g:utest_log_file`            | `''`               |
| `g:utest_log_level`           | `'INFO'`           |

<!--=========================================================================-->

## Contributing

Feedback and feature requests are appreciated.  Bug reports and pull requests
are very welcome.  Check the [Contributing Guidelines][contributing] for how to
write a feature request, post an issue or submit a pull request.

<!--=========================================================================-->

## License

Vim-UTest is licensed under the [MIT license][license].  Copyright (c) 2023
Carlo Delle Donne.

<!--=========================================================================-->

[vim-testify]: https://github.com/dhruvasagar/vim-testify
[vim-UT]: https://github.com/LucHermitte/vim-UT
[vader.vim]: https://github.com/junegunn/vader.vim
[vroom]: https://github.com/google/vroom
[vim-vspec]: https://github.com/kana/vim-vspec
[vim-themis]: https://github.com/thinca/vim-themis
[contributing]: ./CONTRIBUTING.md
[license]: ./LICENSE
