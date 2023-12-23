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
depend on it.  And yes, Vim-UTest supports [mocking](#mocks).

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

To use Vim-UTest, you first define some unit tests.  Then you just run the
`:UTest` command and observe your tests' results.  For an introduction to
writing unit tests using Vim-UTest, see below or run `:help utest`.

Writing a unit tests typically comprises three steps: defining a test fixture,
optionally defining one or more mocks, and defining the test cases themselves.

You can spread your tests over as many test files as you need, which you can for
instance store in a `test/` directory at the root of your project.  The name and
path of this directory are for you to choose.

<!--=========================================================================-->

## Test fixture

Start by creating a test fixture.  The fixture will then be used to define unit
tests and the optional `SetUp()` and `TearDown()` functions.

```vim
let s:fixture = utest#NewFixture()
```

If desired, define `SetUp()` as a dictionary function of the test fixture.  This
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

<!--=========================================================================-->

## Test cases

Define your test cases as dictionary functions of the test fixture.  Make use of
the [functions](#functions) provided by Vim-UTest to set expectations for your
code under test.

A simple test case looks like this:

```vim
function! s:fixture.TestGetResult() abort
    let result = self.component.GetResult(1, 2)
    call utest#ExpectEqual(3, result)
endfunction
```

That's it, you're done writing unit tests.  Or not — if your component under
test depends on other components that you don't want to trigger, but you still
want to check that your component under test issues the appropriate calls to its
dependencies, then it's time to write a mock!

<!--=========================================================================-->

## Mocks

Writing a mock can seem complicated — but it isn't, as long as your component
under test and its dependencies are defined in one of the following ways.

### Dependency is one more autoload functions

Mocks are most simply defined when the component under test depends on one or
more external user-defined functions (internal Vimscript functions cannot be
mocked).  In this case, your component under test is defined in a way that
resembles this simplified example:

```vim
let s:component = {}

function! s:component.GetResult(lhs, rhs) abort
    call myplugin#dependency#CheckOperands(a:lhs, a:rhs)
    let result = myplugin#dependency#ComputeResult(a:lhs, a:rhs)
endfunction

function! myplugin#component#Get() abort
    return s:component
endfunction
```

The external functions to be mocked are those called in the `GetResult()`
function.  To define a test case involving this function, first define a mock
like the following in your test file:

```vim
let s:mock = utest#NewMock([
    \ 'myplugin#dependency#CheckOperands',
    \ 'myplugin#dependency#ComputeResult',
    \ ])
```

Then, define a test case like the following:

```vim
function! s:fixture.TestGetResult() abort
    call utest#ExpectCall(s:mock, 'myplugin#dependency#CheckOperands', [1, 2])
    call utest#ExpectCall(s:mock, 'myplugin#dependency#ComputeResult', [1, 2], 3)
    let result = self.component.GetResult(1, 2)
    call utest#ExpectEqual(3, result)
endfunction
```

The function `utest#ExpectCall()` is used to tell Vim-UTest which mock functions
are expected to be called, in order, throughout the remainder of the test case.
This function takes up to four arguments: a mock object, the name of a mock
function, a list of arguments the mock function is expected to be passed (use
`v:null` to skip checking the arguments), and optionally the value that the mock
function should return when invoked.

### Dependency is an object-like dictionary

The second mocking scenario supported by Vim-UTest is a component which depends
on an object-like dictionary, which is "imported" in the "constructor" of the
component under test. The dependency's dictionary functions are used in the
component under test.  Something like this:

```vim
let s:component = {}

function! s:component.GetResult(lhs, rhs) abort
    call s:dependency.CheckOperands(a:lhs, a:rhs)
    let result = s:dependency.ComputeResult(a:lhs, a:rhs)
endfunction

function! myplugin#component#Get() abort
    let s:dependency = myplugin#dependency#Get()
    return s:component
endfunction
```

This time, you define a mock object by passing the name of the dictionary
functions to be mocked to `utest#NewMock()` and by overriding the dependency's
"constructor" (`myplugin#dependency#Get()`), like below:

```vim
let s:mock = utest#NewMock([
    \ 'CheckOperands',
    \ 'ComputeResult',
    \ ])

call utest#NewMockConstructor(s:mock, 'myplugin#dependency#Get')
```

Then, define a test case like the following:

```vim
function! s:fixture.TestGetResult() abort
    call utest#ExpectCall(s:mock, 'CheckOperands', [1, 2])
    call utest#ExpectCall(s:mock, 'ComputeResult', [1, 2], 3)
    let result = self.component.GetResult(1, 2)
    call utest#ExpectEqual(3, result)
endfunction
```

The function `utest#ExpectCall()` is used as shown above.

<!--=========================================================================-->

## Functions

Use these Vim-UTest functions to create test fixtures and mocks, to define
pre-test and post-test actions, and to set expectations.  A list of functions
follows.  Run `:help utest-functions` for full documentation.

### Creating test fixtures and mocks

| Function                                   | Description                                               |
|:-------------------------------------------|:----------------------------------------------------------|
| `utest#NewFixture()`                       | Create and return a new test fixture object               |
| `utest#NewMock(functions)`                 | Create and return a new mock object                       |
| `utest#NewMockConstructor(mock, function)` | Define a mock "constructor" for an object-like dependency |

### Defining pre-test and post-test actions

| Function                   | Description                                 |
|:---------------------------|:--------------------------------------------|
| `fixture.SetUp()`          | Define actions to be run before each test   |
| `fixture.TearDown()`       | Define actions to be run after each test    |

### Setting simple expectations

Expectations can be specified by using the `Assert` variants of the following
functions or the `Expect` ones.  When an `Assert` function fails, the current
test is stopped.  When an `Expect` function fails instead, the error is
recorded, but the test continues.

| Function                                  | Description                                       |
|:------------------------------------------|:--------------------------------------------------|
| `utest#AssertTrue(expr)`                  | Assert that `expr` is true                        |
| `utest#ExpectTrue(expr)`                  | Expect that `expr` is true                        |
| `utest#AssertFalse(expr)`                 | Assert that `expr` is false                       |
| `utest#ExpectFalse(expr)`                 | Expect that `expr` is false                       |
| `utest#AssertEqual(value, expr)`          | Assert that `expr` is equal to `value`            |
| `utest#ExpectEqual(value, expr)`          | Expect that `expr` is equal to `value`            |
| `utest#AssertNotEqual(value, expr)`       | Assert that `expr` is not equal to `value`        |
| `utest#ExpectNotEqual(value, expr)`       | Assert that `expr` is not equal to `value`        |
| `utest#AssertInRange(lower, upper, expr)` | Assert that `expr` is in range [`lower`, `upper`] |
| `utest#ExpectInRange(lower, upper, expr)` | Expect that `expr` is in range [`lower`, `upper`] |
| `utest#AssertMatch(pattern, expr)`        | Assert that `pattern` matches `expr`              |
| `utest#ExpectMatch(pattern, expr)`        | Expect that `pattern` matches `expr`              |
| `utest#AssertNoMatch(pattern, expr)`      | Assert that `pattern` does not `expr`             |
| `utest#ExpectNoMatch(pattern, expr)`      | Expect that `pattern` does not `expr`             |

### Setting expectations on mocks

To tell Vim-UTest that a mock function is expected to be called, use the
following function.  The arguments to be passed are: the mock object, the name
of the function (as passed to `utest#NewMock()`), a list of the arguments
expected to be passed to the mock function (or `v:null` to skip checking the
arguments), and optionally a value that the mock function should return.

| Function                                           | Description                           |
|:---------------------------------------------------|:--------------------------------------|
| `utest#ExpectCall(mock, function, args, [return])` | Expect future call to a mock function |

<!--=========================================================================-->

## Commands

When you're done writing unit tests and mocks, you just run the `:UTest`
command.  You will observe a report of the outcomes of your unit tests as the
test functions are executed.  The command is used as below, where `[path]` is
the path to a file or directory containing unit tests.  Run `:help
utest-commands` for full documentation.

```vim
:UTest [path] [--name <testname>] [--cursor]
```

<!--=========================================================================-->

## Events

Vim-UTest provides a set of custom events to trigger further actions upon
completion of the `:UTest` command.

| Event                      | Description                                            |
|:---------------------------|:-------------------------------------------------------|
| `User UTestTestsSucceeded` | Triggered after a successful test run                  |
| `User UTestTestsFailed`    | Triggered after a failed test run                      |
| `User UTestTestsAborted`   | Triggered after a test was aborted due to an exception |

Example usage of `UTestTestsFailed` to jump to the first error

```vim
let g:utest_focus_on_error = 0  " We do not want to focus the buffer
augroup vim-utest-group
autocmd User UTestTestsFailed cfirst
augroup END
```

<!--=========================================================================-->

## Quickfix list

After each test run, Vim-UTest populates a quickfix list to speed up the
workflow.  Upon an unsuccessful test run, just use the standard quickfix
commands to open the list of errors (e.g. `:copen`) and jump between errors
(e.g. `:cfirst`, `:cnext`).

<!--=========================================================================-->

## Running tests from the command line

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
use `:verbose` for them to be displayed.

<!--=========================================================================-->

## Configuration

Vim-UTest has sensible defaults, but aims to be configurable.  A list of
configuration options, with default values, follows.  Run `:help
utest-configuration` for full documentation on all the configuration options.  

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
[vim-plug]: https://github.com/junegunn/vim-plug
[contributing]: ./CONTRIBUTING.md
[license]: ./LICENSE
