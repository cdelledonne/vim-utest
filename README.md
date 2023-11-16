# Vim-UTest

Vim-UTest is a plugin to unit-test Vimscript code.  It has also mocking support.
It can be run from within Vim/Neovim as well as from the command line.

![tests](https://img.shields.io/github/actions/workflow/status/cdelledonne/vim-utest/test.yaml?label=tests)
![language](https://img.shields.io/github/languages/top/cdelledonne/vim-utest)
![version](https://img.shields.io/github/v/tag/cdelledonne/vim-utest?label=version&sort=semver)
![license](https://img.shields.io/github/license/cdelledonne/vim-utest)

**Features**

* Test cases are simply written in Vimscript
* Support for test fixtures with optional setup and tear-down
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
