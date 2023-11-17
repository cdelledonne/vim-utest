" ==============================================================================
" Location:    autoload/utest/test.vim
" Description: Unit testing and mocking
" ==============================================================================

let s:test = {}
let s:test.tests = {}
let s:test.qflist_id = -1

let s:assert = utest#assert#Get()
let s:const = utest#const#Get()
let s:quickfix = libs#quickfix#Get()
let s:report = utest#report#Get()
let s:system = libs#system#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:error = libs#error#Get(s:const.plugin_name, s:logger)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:ParseRunArgs(args) abort
    let tests = []
    let cursor = v:false
    " Parse arguments.
    let parser = libs#argparser#New()
    call parser.AddArgument('path', '?')
    call parser.AddArgument('--name', '*')
    call parser.AddArgument('--cursor', '?', 'store_true')
    let opts = parser.Parse(a:args)
    let path = remove(opts, 'path')
    let path = path is v:null ? g:utest_default_test_dir : path
    let path = s:system.Path([path], v:false)
    " Check test path.
    if s:system.FileIsReadable(path)
        let files = [path]
    elseif s:system.DirectoryExists(path)
        let files = s:system.Glob(path . '/**/*.vim')
    else
        call s:error.Throw('NO_SUCH_PATH', string(path))
    endif
    " Process other arguments.
    if has_key(opts, 'name')
        let tests = type(opts.name) == v:t_list ? opts.name : [opts.name]
    endif
    if has_key(opts, 'cursor')
        if opts.cursor
            " TODO: retrieve name of test at or above cursor
            " TODO: check that only one of --name and --cursor is used
            call s:error.Throw('OPT_NOT_IMPLEMENTED', string('--cursor'))
        endif
    endif
    return [files, tests, cursor]
endfunction

function! s:CheckSelectedTestsExist(selected_tests, all_tests) abort
    " Make list of all tests.
    let test_name_dicts = map(values(a:all_tests), {_, v -> values(v)})
    let flattened_test_name_dicts = flatten(test_name_dicts)
    let test_names = map(flattened_test_name_dicts, {_, v -> v.funcname})
    call uniq(test_names)
    " Check that selected tests is a subset of all tests.
    for test in a:selected_tests
        if !s:system.ListHas(test_names, test)
            call s:error.Throw('TEST_DOES_NOT_EXIST', string(test))
        endif
    endfor
endfunction

function! s:RunTest(funcname, test) abort
    let error_list = []
    let a:test.setup_running = v:false
    let a:test.teardown_running = v:false
    call s:report.ReportTestInfo('Running test ''%s''', a:funcname)
    call s:logger.LogDebug('Running test ''%s''', a:funcname)
    " Run the SetUp() function. If this does not run successfully, we won't run
    " the test function (nor the TearDown() function).
    try
        let a:test.setup_running = v:true
        call a:test.fixture.SetUp()
    catch /vim-utest-assert-failed/
    finally
        let a:test.setup_running = v:false
    endtry
    " The test function and the TearDown() function are only run if the SetUp()
    " function succeeded (i.e. no errors recorded so far).
    if len(a:test.errors) == 0
        try
            call a:test.funcref(a:test.fixture)
        catch /vim-utest-assert-failed/
        endtry
        " The TearDown() function is run whether or not the test function as
        " incurred any errors.
        try
            let a:test.teardown_running = v:true
            call a:test.fixture.TearDown()
        catch /vim-utest-assert-failed/
        finally
            let a:test.teardown_running = v:false
        endtry
    endif
    if len(a:test.errors) > 0
        for error in a:test.errors
            let fmt = '%s:%d: Error: %s'
            let error_args = [fmt, a:test.file, error.lnum, error.msg]
            call call(funcref('s:report.ReportTestError'), error_args, s:report)
            call call(funcref('s:logger.LogDebug'), error_args, s:logger)
            call add(error_list, call('printf', error_args))
        endfor
        call s:report.ReportTestError('Test failed')
        call s:logger.LogDebug('Test failed')
    else
        call s:report.ReportTestInfo('Test passed')
        call s:logger.LogDebug('Test passed')
    endif
    return error_list
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Create new test fixture.
"
" Returns:
"     Dictionary
"         test fixture
"
function! s:test.NewFixture() abort
    call s:logger.LogDebug('Invoked: test.NewFixture()')
    return {
        \ 'SetUp': {-> 0},
        \ 'TearDown': {-> 0},
        \ }
endfunction

" Create new mock object.
"
" Mock objects represent dependencies of the component under test. Store the
" returned mock object into test fixture.
"
" Params:
"     functions : List
"         list of functions to mock, where each item is a dictionary consisting
"         of two entries: 'name' - the function's name, and 'ref' - a reference
"         to the function to be mocked (the 'ref' key is only necessary when the
"         function to be mocked is not a dict function)
"
" Returns:
"     Dictionary
"         mock object
"
function! s:test.NewMock(functions) abort
    call s:logger.LogDebug('Invoked: test.NewMock(%s)', a:functions)
    let mock = {}
    for function in a:functions
        " TODO: Funcref should have a proper definition
        let Funcref = {-> 0}
        let mock[function.name] = Funcref
        if has_key(function, 'ref')
            execute 'let ' . function.ref ' = Funcref'
        endif
    endfor
    return mock
endfunction

" Add function to list of tests.
"
" Params:
"     funcref : Funcref
"         function to run as test
"     fixture : Dictionary
"         test fixture, as returned by AddFixture(), or v:null
"
function! s:test.AddTest(funcref, fixture) abort
    call s:logger.LogDebug(
        \ 'Invoked: test.AddTest(%s, %s)', a:funcref, a:fixture)
    " Extract file and line of function definition, also for SetUp() and
    " TearDown() functions.
    let [file, func_lnum] = s:system.GetFunctionInfo(a:funcref)
    let [setup_lnum, teardown_lnum] = [v:null, v:null]
    let [_, setup_lnum] = s:system.GetFunctionInfo(a:fixture.SetUp)
    let [_, teardown_lnum] = s:system.GetFunctionInfo(a:fixture.TearDown)
    " Also extract function name of test function.
    let funcname = matchlist(
        \ string(a:funcref),
        \ '\m\Cfunction(''\(<SNR>\d\+_\)\?\(.*\)'')'
        \ )[2]
    " Create dictionary of tests for this file, if it doesn't exist.
    if !has_key(self.tests, file)
        let self.tests[file] = {}
    endif
    " Check if test already exists in this test file.
    let funcnames = map(values(self.tests[file]), {_, v -> v.funcname})
    if s:system.ListHas(funcnames, funcname)
        call s:error.Throw('TEST_EXISTS', string(funcname), string(file))
    endif
    " Add test to dictionary.
    let test = {
        \ 'funcname': funcname,
        \ 'funcref': a:funcref,
        \ 'file': file,
        \ 'func_lnum': func_lnum,
        \ 'setup_lnum': setup_lnum,
        \ 'teardown_lnum': teardown_lnum,
        \ 'fixture': a:fixture,
        \ 'errors': [],
        \ }
    let id = len(self.tests[file])
    let self.tests[file][id] = test
    call s:logger.LogDebug('Added test %s: %s', string(funcname), test)
endfunction

" Run tests in a certain directory or file.
"
" Params:
"     args : List
"         directory or file to scan for tests and additional :UTest arguments
"
" Returns:
"     Number
"         number of failed tests
"
" Notes:
"     - By default, all tests found in path are run
"     - The options name and cursor are mutually exclusive - if both are
"       specified, the function exits with an error
"
function! s:test.RunTests(args) abort
    call s:logger.LogDebug('Invoked: test.Run(%s)', a:args)
    let self.tests = {}
    let num_tests = 0
    let num_failed_tests = 0
    let error_list = []
    call s:report.Reset()
    if g:utest_focus
        call s:report.Focus()
    endif
    call s:report.ReportInfo('Running Vim-UTest')
    try
        let [files, selected_tests, cursor] = s:ParseRunArgs(a:args)
        let run_all = len(selected_tests) > 0 ? v:false : v:true
        " Source test files - list of tests is populated here.
        for file in files
            call s:system.Source(file)
        endfor
        " Check that selected tests match at least one existing test each.
        if !run_all
            call s:CheckSelectedTestsExist(selected_tests, self.tests)
        endif
        " Run tests, going through test files in alphabetical order.
        for file in sort(keys(self.tests))
            call s:report.ReportInfo('Running tests in file %s', file)
            call s:logger.LogDebug('Running tests in file %s', file)
            " Sort tests by ID - tests that were defined first have a lower ID.
            " Note: in the following lambda, 'i' is the item (the test), and
            " '[0]' is the key of the item (the ID).
            let tests = sort(items(self.tests[file]), {i -> str2nr(i[0])})
            for [id, test] in tests
                " Only run this test if all tests are to be run or if a test was
                " selected explicitly.
                if run_all || s:system.ListHas(selected_tests, test.funcname)
                    let num_tests += 1
                    call s:assert.SetCurrentTest(test)
                    let current_error_list = s:RunTest(test.funcname, test)
                    let num_failed_tests += len(current_error_list) > 0 ? 1 : 0
                    call extend(error_list, current_error_list)
                endif
            endfor
        endfor
    catch /.*/
        let num_failed_tests = 1
        call s:report.ReportTestError(v:throwpoint)
        call s:report.ReportTestError(v:exception)
        call s:report.ReportInfo('Tests aborted due to uncaught exception')
        return num_failed_tests
    finally
        if g:utest_focus_on_completion ||
            \ (g:utest_focus_on_error && num_failed_tests > 0)
            call s:report.Focus()
        endif
    endtry
    " Generate Quickfix list for reported errors.
    let self.qflist_id = s:quickfix.Generate(
        \ error_list, self.qflist_id, 'Vim-UTest')
    " Report (and log) final stats.
    let num_passed_tests = num_tests - num_failed_tests
    call s:report.ReportInfo('Total tests: %d', num_tests)
    call s:report.ReportInfo('Passed: %d', num_passed_tests)
    call s:report.ReportInfo('Failed: %d', num_failed_tests)
    call s:logger.LogDebug('Total tests: %d, Passed: %d, Failed: %d',
        \ num_tests, num_passed_tests, num_failed_tests
        \ )
    return num_failed_tests
endfunction

" Get test 'object'.
"
function! utest#test#Get() abort
    return s:test
endfunction
