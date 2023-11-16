if exists('b:current_syntax')
    finish
endif
let b:current_syntax = 'utest'

syntax region UTestWarn start=/\m\C^\[ \~ \~ \~ \~ \]/ end=/\m\C$/
syntax region UTestError start=/\m\C^\[ X X X X \]/ end=/\m\C$/

if !hlexists('DiagnosticWarn') || !hlexists('DiagnosticError')
    highlight DiagnosticWarn ctermfg=3 guifg=Orange
    highlight DiagnosticError ctermfg=1 guifg=Red
endif

highlight default link UTestWarn DiagnosticWarn
highlight default link UTestError DiagnosticError
