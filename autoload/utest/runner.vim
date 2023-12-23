" ==============================================================================
" Location:    autoload/utest/runner.vim
" Description: Top-level execution manager for :UTest
" ==============================================================================

let s:runner = {}
let s:runner.sourced_test_files = {}
let s:runner.fixtures = []
let s:runner.mocks = []
let s:runner.qflist_id = -1

let s:assert = utest#assert#Get()
let s:const = utest#const#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:error = libs#error#Get(s:const.plugin_name, s:logger)
let s:quickfix = libs#quickfix#Get()
let s:report = utest#report#Get()
let s:system = libs#system#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:runner._MockConstructor(mock) abort
    return a:mock
endfunction

function! s:runner._OverrideAutoloadFuncs() abort
    for mock in self.current_fixture._GetMocks()
        call mock._OverrideAutoloadFuncs()
    endfor
endfunction

function! s:runner._RestoreAutoloadFuncs() abort
    for mock in self.current_fixture._GetMocks()
        call mock._RestoreAutoloadFuncs()
    endfor
endfunction

function! s:runner._OnSourcePost() abort
    " When sourcing an autoload file (of a dependency component), we override
    " the autoload mock functions, so that the actual autoload functions are
    " replaced by mocks.
    call self._OverrideAutoloadFuncs()
endfunction

function! s:runner._SetCurrentTest(test) abort
    call s:assert.SetCurrentTest(a:test)
    for mock in self.mocks
        call mock._SetCurrentTest(a:test)
    endfor
endfunction

function! s:runner._ParseRunArgs(args) abort
    let tests = []
    let cursor = v:false
    " Parse arguments.
    let parser = libs#argparser#New()
    call parser.AddArgument('path', '?')
    call parser.AddArgument('--name', '*')
    call parser.AddArgument('--cursor', '?', 'store_true')
    let opts = parser.Parse(a:args)
    let path = opts.path is v:null ? g:utest_default_test_dir : opts.path
    let path = s:system.Path(path, v:false)
    " Process other arguments.
    let tests = type(opts.name) == v:t_list ? opts.name : [opts.name]
    if opts.cursor
        " The option --cursor cannot be used in headless/silent mode.
        if s:system.VimIsStarting()
            call s:error.Throw('CANT_USE_CURSOR_IN_HEADLESS')
        endif
        " The option --cursor does not expect any path.
        if opts.path isnot v:null
            call s:error.Throw('UNEXPECTED_PATH_ARG')
        endif
        " The options --cursor and --name are mutually exclusive, using both
        " results in an error.
        if tests != []
            call s:error.Throw(
                \ 'CONFLICTING_ARGS', string('--cursor'), string('--name'))
        endif
        let cursor = v:true
    endif
    return [path, tests, cursor]
endfunction

function! s:runner._ScanTestFiles(files) abort
    " Source test files to discover test fixtures and mocks, then compile list
    " of tests for each fixture.
    for file in a:files
        " If a test file had already been sourced and has not been modified
        " since, just use the cached test fixtures and mocks already discovered.
        if has_key(self.sourced_test_files, file) &&
            \ getftime(file) == self.sourced_test_files[file].ftime
            call s:logger.LogDebug(
                \ 'File %s already sourced, using cached fixtures and mocks',
                \ string(file)
                \ )
            call extend(self.fixtures, self.sourced_test_files[file].fixtures)
            call extend(self.mocks, self.sourced_test_files[file].mocks)
        " Otherwise, (re)source the test file, compile tests in fixtures found,
        " and cache test fixtures and mocks.
        else
            call s:logger.LogDebug('(Re)sourcing file %s', string(file))
            let first_new_fixture_idx = len(self.fixtures)
            let first_new_mock_idx = len(self.mocks)
            call s:system.Source(file)
            let fixtures_this_file = self.fixtures[first_new_fixture_idx :]
            let mocks_this_file = self.mocks[first_new_mock_idx :]
            for fixture in fixtures_this_file
                call fixture._CompileTests()
            endfor
            let self.sourced_test_files[file] = {
                \ 'ftime': getftime(file),
                \ 'fixtures': fixtures_this_file,
                \ 'mocks': mocks_this_file,
                \ }
        endif
    endfor
endfunction

function! s:runner._CheckExpectedCalls(test) abort
    let expected_calls = []
    for mock in self.mocks
        call extend(expected_calls, mock._GetExpectedCalls())
    endfor
    for call in expected_calls
        " Extract line number where expectation was set.
        if a:test.setup_running
            let func_lnum = a:test.setup_lnum
        elseif a:test.teardown_running
            let func_lnum = a:test.teardown_lnum
        else
            let func_lnum = a:test.start_lnum
        endif
        let error_lnum = func_lnum + str2nr(call.relative_expectation_lnum)
        " Add error to list of errors to be reported.
        let error_descr = printf(
            \ 'Unmatched expected call to function ''%s(%s)''',
            \ call.funcname,
            \ string(call.args)[1:-2]
            \ )
        let error_func_name = 'ExpectCall'
        let error_msg = printf('%s (%s)', error_descr, error_func_name)
        call add(a:test.errors, {'msg': error_msg, 'lnum': error_lnum})
    endfor
endfunction

function! s:runner._RunTest(fixture, test) abort
    let error_list = []
    for mock in self.mocks
        call mock._Reset()
    endfor
    let a:test.errors = []
    let a:test.setup_running = v:false
    let a:test.teardown_running = v:false
    call s:report.ReportTestInfo('Running test ''%s''', a:test.funcname)
    call s:logger.LogDebug('Running test ''%s''', a:test.funcname)
    " Run the SetUp() function. If this does not run successfully, we won't run
    " the test function (nor the TearDown() function).
    try
        let a:test.setup_running = v:true
        call a:fixture.SetUp()
    catch /vim-utest-assert-failed/
        call add(a:test.errors, {'msg': 'Test aborted due to assert error'})
    finally
        let a:test.setup_running = v:false
    endtry
    " The test function and the TearDown() function are only run if the SetUp()
    " function succeeded (i.e. no errors recorded so far).
    if len(a:test.errors) == 0
        try
            call a:fixture[a:test.funcname]()
        catch /vim-utest-assert-failed/
            call add(a:test.errors, {'msg': 'Test aborted due to assert error'})
        endtry
        " The TearDown() function is run whether or not the test function as
        " incurred any errors.
        try
            let a:test.teardown_running = v:true
            call a:fixture.TearDown()
        catch /vim-utest-assert-failed/
            call add(a:test.errors, {'msg': 'Test aborted due to assert error'})
        finally
            let a:test.teardown_running = v:false
        endtry
    endif
    " Check if all expected mock calls have been issued.
    call self._CheckExpectedCalls(a:test)
    " Report and log errors.
    if len(a:test.errors) > 0
        for error in a:test.errors
            if !has_key(error, 'lnum')
                call s:report.ReportTestError(error.msg)
                call s:logger.LogDebug(error.msg)
                continue
            endif
            let fmt = '%s:%d: Error: %s'
            let test_file = s:system.Path(a:test.file, v:true)
            let error_args = [fmt, test_file, error.lnum, error.msg]
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
function! s:runner.NewFixture() abort
    call s:logger.LogDebug('Invoked: runner.NewFixture()')
    let fixture = utest#fixture#New()
    call add(self.fixtures, fixture)
    return fixture
endfunction

" Create new mock object. Mock objects represent dependencies of the component
" under test.
"
" Params:
"     fixture : Dictionary
"         fixture object, as returned by utest#NewFixture()
"     functions : List
"         list of function names to mock, each item can be either an autoload
"         function (like 'plugin#component#SomeFunc') or a dictionary function
"         (like 'SomeFunc') - these function names can then be passed to
"         utest#ExpectCall()
"
" Returns:
"     Dictionary
"         mock object
"
" Notes:
"     - Function names that contain a '#' character are assumed to be autoload
"       functions, whilst those that do not contain any '#' character are
"       assumed to be dictionary functions
"     - When the function to be mocked is a dictionary function of the
"       component, like component.SomeFunc(), the name in the list of functions
"       must just be the name of the dictionary key, in this example 'SomeFunc'
"
function! s:runner.NewMock(fixture, functions) abort
    call s:logger.LogDebug('Invoked: runner.NewMock(%s)', a:functions)
    let mock = utest#mock#New(a:functions)
    call add(self.mocks, mock)
    call a:fixture._RegisterMock(mock)
    return mock
endfunction

" Define new mock constructor function.
"
" Params:
"     mock : Dictionary
"         mock object, as returned by utest#NewMock()
"     function : String
"         name of constructor function to mock (an autoload function)
"
function! s:runner.NewMockConstructor(mock, function) abort
    call s:logger.LogDebug('Invoked: runner.NewMockConstructor(%s, %s)',
        \ a:mock.id, a:function)
    call a:mock._AddMockConstructor(
        \ a:function, funcref('self._MockConstructor', [a:mock], self))
endfunction

" Recursively scan path to discover tests.
"
" Params:
"     path : String
"         file or directory to scan
"     a:1 (noexcept) : Boolean
"         if set to v:true, this function will not throw exceptions (useful e.g.
"         when called to provide autocompletion for test names)
"
" Returns:
"     List
"         names of tests found
"
function! s:runner.DiscoverTests(path, ...) abort
    let noexcept = exists('a:1') ? a:1 : v:false
    " Scan path recursively for test files.
    if s:system.FileIsReadable(a:path)
        let files = [s:system.Path(a:path, v:false)]
    elseif s:system.DirectoryExists(a:path)
        let files = s:system.Glob(a:path . '/**/*.vim', v:false)
    else
        if noexcept
            call s:logger.LogWarn(
                \ 'runner.DiscoverTests() failed, ' .
                \ 'path %s is invalid', string(a:path)
                \ )
            return
        else
            call s:error.Throw('NO_SUCH_PATH', string(a:path))
        endif
    endif
    let self.fixtures = []
    let self.mocks = []
    if noexcept
        try
            call self._ScanTestFiles(files)
        catch /.*/
            call s:logger.LogWarn(
                \ 'runner.DiscoverTests() failed, ' .
                \ 'exception thrown from runner._ScanTestFiles()'
                \ )
        endtry
    else
        call self._ScanTestFiles(files)
    endif
    " Make list of all tests.
    let test_dicts = []
    for fixture in self.fixtures
        call extend(test_dicts, fixture._GetTests())
    endfor
    let test_names = map(test_dicts, {_, v -> v.funcname})
    return uniq(test_names)
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
function! s:runner.RunTests(args) abort
    call s:logger.LogDebug('Invoked: runner.Run(%s)', a:args)
    let num_tests = 0
    let num_failed_tests = 0
    let error_list = []
    call s:report.Reset()
    if g:utest_focus
        call s:report.Focus()
    endif
    call s:report.ReportInfo('Running Vim-UTest')
    try
        let [path, selected_tests, cursor] = self._ParseRunArgs(a:args)
        let run_all = (len(selected_tests) > 0 || cursor) ? v:false : v:true
        " When the test under the cursor is to be run, we only scan the file in
        " the current buffer.
        if cursor
            let path = s:system.Path(bufname('%'), v:false)
        endif
        let test_names = self.DiscoverTests(path)
        " When the test under the cursor is to be run, we lookup the name of the
        " function under the cursor in the discovered test fixtures.
        if cursor
            let cursor_line = line('.')
            let found = v:false
            for fixture in self.fixtures
                let test_under_cursor = fixture._SearchTest(path, cursor_line)
                if test_under_cursor !=# ''
                    let selected_tests = [test_under_cursor]
                    let found = v:true
                    break
                endif
            endfor
            if !found
                call s:error.Throw('NO_TEST_UNDER_CURSOR')
            endif
        endif
        " Check that if some tests were explicitly selected, these tests match
        " at least one existing test each.
        if len(selected_tests) > 0
            for test in selected_tests
                if !s:system.ListHas(test_names, test)
                    call s:error.Throw('TEST_DOES_NOT_EXIST', string(test))
                endif
            endfor
        endif
        " Run tests, going through test fixtures in the order they were
        " discovered in the sourced files.
        for fixture in self.fixtures
            let self.current_fixture = fixture
            " Override mocks' autoload functions. This only works if the actual
            " autoload functions have already been loaded. We also define an
            " autocmd to override the functions when sourcing the corresponding
            " autoload files, in case these haven't been sourced yet.
            call self._OverrideAutoloadFuncs()
            call s:system.AutocmdSet(
                \ 'SourcePost',
                \ '*',
                \ 'call utest#runner#Get()._OnSourcePost()',
                \ 'vimutest-mock'
                \ )
            let fixture_file = s:system.Path(fixture.file, v:true)
            call s:report.ReportInfo('Running tests in file %s', fixture_file)
            call s:logger.LogDebug('Running tests in file %s', fixture_file)
            for test in fixture._GetTests()
                " Only run this test if all tests are to be run or if a test was
                " selected explicitly.
                if run_all || s:system.ListHas(selected_tests, test.funcname)
                    let num_tests += 1
                    call self._SetCurrentTest(test)
                    let current_error_list = self._RunTest(fixture, test)
                    let num_failed_tests += len(current_error_list) > 0 ? 1 : 0
                    call extend(error_list, current_error_list)
                endif
            endfor
            " Delete autocmd to override mocks' autoload functions, then restore
            " original autoload functions. Must be done in this order because
            " _RestoreAutoloadFuncs() might source some files, and thus the
            " 'SourcePost' event should not trigger the autocmd.
            call s:system.AutocmdDelete('SourcePost', '*', 'vimutest-mock')
            call self._RestoreAutoloadFuncs()
        endfor
    catch /.*/
        let num_failed_tests = 1
        call s:report.ReportTestError(v:throwpoint)
        call s:report.ReportTestError(v:exception)
        call s:report.ReportInfo('Tests aborted due to uncaught exception')
        call s:system.AutocmdRun('UTestTestsAborted')
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
    let evt = num_failed_tests > 0 ? 'UTestTestsFailed' : 'UTestTestsSucceeded'
    call s:system.AutocmdRun(evt)
    return num_failed_tests
endfunction

" Get runner 'object'.
"
function! utest#runner#Get() abort
    return s:runner
endfunction
