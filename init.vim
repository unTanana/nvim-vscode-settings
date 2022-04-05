" options
" This file used to force set neovim options which may break the extension. Loaded after user config

scriptencoding utf-8

set shortmess=filnxtToOFI
set nowrap
set mouse=a
set cmdheight=1
set wildmode=list
set wildchar=<C-e>
set clipboard=unnamed

set nobackup
set nowb
set noswapfile
set noautoread
set scrolloff=100
set conceallevel=0
set nocursorline

" do not hide buffers
" set nohidden
set hidden
set bufhidden=hide
" do not attempt autowrite any buffers
set noautowrite
" Disable shada session storing
" set shada=
" set nonumber
set norelativenumber
" Render line number as "marker" of the visible top/bottom screen row
set nonumber
" up to 10 000 000
" set numberwidth=8
" Need to know tabs for HL
set listchars=tab:❥♥
set list
" Allow to use vim HL for external buffers, vscode buffers explicitly disable it
syntax on
set signcolumn=no

" Disable statusline and ruler since we don't need them anyway
set statusline=
set laststatus=0
set noruler

" Disable modeline processing. It's being used for tab related settings usually and we don't want to override ours
set nomodeline
set modelines=0

" Turn off auto-folding
set nofoldenable
set foldmethod=manual

" Turn on auto-indenting
set autoindent
set smartindent

" split/nosplit doesn't work currently, see https://github.com/asvetliakov/vscode-neovim/issues/329
set inccommand=

" lazyredraw breaks the movement
set nolazyredraw

function s:forceLocalOptions()
    setlocal nowrap
    setlocal conceallevel=0
    setlocal scrolloff=100
    setlocal hidden
    setlocal bufhidden=hide
    setlocal noautowrite
    setlocal nonumber
    setlocal norelativenumber
    setlocal list
    setlocal listchars=tab:❥♥
    if exists('b:vscode_controlled') && b:vscode_controlled
        setlocal syntax=off
    endif
    setlocal nofoldenable
    setlocal foldmethod=manual
    setlocal nolazyredraw
endfunction

augroup VscodeForceOptions
    autocmd!
    autocmd BufEnter,FileType * call <SID>forceLocalOptions()
augroup END

if exists('g:vscode')
    " VSCode ONLY stuff

    " neovim
    " Set global flag to allow checking in custom user config
    let g:vscode = 1

    let s:currDir = fnamemodify(resolve(expand('<sfile>:p')), ':h')
    " Adjust rtp path
    let &runtimepath = &runtimepath . ',' . s:currDir . '/vim-altercmd'

    " Used to execute vscode command
    let s:vscodeCommandEventName = 'vscode-command'
    " Used to execute vscode command with some range (the specified range will be selected and the command will be executed on this range)
    let s:vscodeRangeCommandEventName = 'vscode-range-command'
    " Used for externsion inter-communications
    let s:vscodePluginEventName = 'vscode-neovim'

    " RPC and global functions

    function! VSCodeCall(cmd, ...) abort
        call rpcrequest(g:vscode_channel, s:vscodeCommandEventName, a:cmd, a:000)
    endfunction

    function! VSCodeNotify(cmd, ...)
        call rpcnotify(g:vscode_channel, s:vscodeCommandEventName, a:cmd, a:000)
    endfunction

    function! VSCodeCallRange(cmd, line1, line2, leaveSelection, ...) abort
        call rpcrequest(g:vscode_channel, s:vscodeRangeCommandEventName, a:cmd, a:line1, a:line2, 0, 0, a:leaveSelection, a:000)
    endfunction

    function! VSCodeNotifyRange(cmd, line1, line2, leaveSelection, ...)
        call rpcnotify(g:vscode_channel, s:vscodeRangeCommandEventName, a:cmd, a:line1, a:line2, 0, 0, a:leaveSelection, a:000)
    endfunction

    function! VSCodeCallRangePos(cmd, line1, line2, pos1, pos2, leaveSelection, ...) abort
        call rpcrequest(g:vscode_channel, s:vscodeRangeCommandEventName, a:cmd, a:line1, a:line2, a:pos1, a:pos2, a:leaveSelection, a:000)
    endfunction

    function! VSCodeNotifyRangePos(cmd, line1, line2, pos1, pos2, leaveSelection, ...)
        call rpcnotify(g:vscode_channel, s:vscodeRangeCommandEventName, a:cmd, a:line1, a:line2, a:pos1, a:pos2, a:leaveSelection, a:000)
    endfunction

    function! VSCodeExtensionCall(cmd, ...) abort
        call rpcrequest(g:vscode_channel, s:vscodePluginEventName, a:cmd, a:000)
    endfunction

    function! VSCodeExtensionNotify(cmd, ...)
        call rpcnotify(g:vscode_channel, s:vscodePluginEventName, a:cmd, a:000)
    endfunction

    function! VSCodeCallVisual(cmd, leaveSelection, ...) abort
        let mode = mode()
        if mode ==# 'V'
            let startLine = line('v')
            let endLine = line('.')
            call VSCodeCallRange(a:cmd, startLine, endLine, a:leaveSelection, a:000)
        elseif mode ==# 'v' || mode ==# "\<C-v>"
            let startPos = getpos('v')
            let endPos = getpos('.')
            call VSCodeCallRangePos(a:cmd, startPos[1], endPos[1], startPos[2], endPos[2] + 1, a:leaveSelection, a:000)
        else
            call VSCodeCall(a:cmd, a:000)
        endif
    endfunction

    function! VSCodeNotifyVisual(cmd, leaveSelection, ...)
        let mode = mode()
        if mode ==# 'V'
            let startLine = line('v')
            let endLine = line('.')
            call VSCodeNotifyRange(a:cmd, startLine, endLine, a:leaveSelection, a:000)
        elseif mode ==# 'v' || mode ==# "\<C-v>"
            let startPos = getpos('v')
            let endPos = getpos('.')
            call VSCodeNotifyRangePos(a:cmd, startPos[1], endPos[1], startPos[2], endPos[2] + 1, a:leaveSelection, a:000)
        else
            call VSCodeNotify(a:cmd, a:000)
        endif
    endfunction

    " Called from extension when opening/creating new file in vscode to reset undo tree
    function! VSCodeClearUndo(bufId)
        let oldlevels = &undolevels
        call nvim_buf_set_option(a:bufId, 'undolevels', -1)
        call nvim_buf_set_lines(a:bufId, 0, 0, 0, [])
        call nvim_buf_set_option(a:bufId, 'undolevels', oldlevels)
        unlet oldlevels
    endfunction

    " Set text decorations for given ranges. Used in easymotion
    function! VSCodeSetTextDecorations(hlName, rowsCols)
        call VSCodeExtensionNotify('text-decorations', a:hlName, a:rowsCols)
    endfunction

    " Used for ctrl-a insert keybinding
    function! VSCodeGetLastInsertText()
        let [lineStart, colStart] = getpos("'[")[1:2]
        let [lineEnd, colEnd] = getpos("']")[1:2]
        if (lineStart == 0)
            return []
        endif
        let lines = getline(lineStart, lineEnd)
        let lines[0] = lines[0][colStart - 1:]
        let lines[-1] = lines[-1][:colEnd - 1]
        return lines
    endfunction

    " Used for ctrl-r [reg] insert keybindings
    function! VSCodeGetRegister(reg)
        return getreg(a:reg)
    endfunction

    " This is called by extension when created new buffer
    function! s:onBufEnter(name, id)
        if exists('b:vscode_temp') && b:vscode_temp
            return
        endif
        set conceallevel=0
        let tabstop = &tabstop
        let isJumping = 0
        if exists('g:isJumping')
            let isJumping = g:isJumping
        endif
        call VSCodeExtensionCall('external-buffer', a:name, a:id, 1, tabstop, isJumping)
    endfunction

    function! s:runFileTypeDetection()
        doautocmd BufRead
        if exists('b:vscode_controlled') && b:vscode_controlled
            " make sure we disable syntax (global option seems doesn't take effect for 2nd+ windows)
            setlocal syntax=off
        endif
    endfunction

    function! s:onInsertEnter()
        let reg = reg_recording()
        if !empty(reg)
            call VSCodeExtensionCall('notify-recording', reg)
        endif
    endfunction


    " Load altercmd first
    execute 'source ' . s:currDir . '/vim-altercmd/plugin/altercmd.vim'
    execute 'source ' . s:currDir . '/vscode-insert.vim'
    execute 'source ' . s:currDir . '/vscode-scrolling.vim'
    execute 'source ' . s:currDir . '/vscode-jumplist.vim'
    execute 'source ' . s:currDir . '/vscode-code-actions.vim'
    execute 'source ' . s:currDir . '/vscode-file-commands.vim'
    execute 'source ' . s:currDir . '/vscode-tab-commands.vim'
    execute 'source ' . s:currDir . '/vscode-window-commands.vim'
    execute 'source ' . s:currDir . '/vscode-motion.vim'

    augroup VscodeGeneral
        autocmd!
        " autocmd BufWinEnter,WinNew,WinEnter * :only
        autocmd BufWinEnter * call <SID>onBufEnter(expand('<afile>'), expand('<abuf>'))
        " Help and other buffer types may explicitly disable line numbers - reenable them, !important - set nowrap since it may be overriden and this option is crucial for now
        " autocmd FileType * :setlocal conceallevel=0 | :setlocal number | :setlocal numberwidth=8 | :setlocal nowrap | :setlocal nofoldenable
        autocmd InsertEnter * call <SID>onInsertEnter()
        autocmd BufAdd * call <SID>runFileTypeDetection()
        " Looks like external windows are coming with "set wrap" set automatically, disable them
        " autocmd WinNew,WinEnter * :set nowrap
    augroup END

    nnoremap <silent> <Space> :call VSCodeNotify('whichkey.show')<CR>
    xnoremap <silent> <Space> :call VSCodeNotify('whichkey.show')<CR>

    nmap s <Plug>(easymotion-s2)
    nmap t <Plug>(easymotion-t2)
    inoremap jk <esc>
endif

" plugins
function! Cond(Cond, ...)
  let opts = get(a:000, 0, {})
  return a:Cond ? opts : extend(opts, { 'on': [], 'for': [] })
endfunction

call plug#begin()
    Plug 'easymotion/vim-easymotion', Cond(!exists('g:vscode'))
    Plug 'asvetliakov/vim-easymotion', Cond(exists('g:vscode'), { 'as': 'vsc-easymotion' })
call plug#end()
