let s:supports_floating = exists('*nvim_open_win')
let s:win = v:false

function! lsp#ui#vim#output#closepreview() abort
  if win_getid() == s:win
    " Don't close if window got focus
    return
  endif
  pclose
  let s:win = v:false
  autocmd! lsp_float_preview_close CursorMoved,CursorMovedI,VimResized *
endfunction

function! s:get_float_positioning(height, width) abort
    let l:height = a:height
    let l:width = a:width
    " For a start show it below/above the cursor
    " TODO: add option to configure it 'docked' at the bottom/top/right
    let l:y = winline()
    if l:y + l:height >= &lines
      " Float does not fit
      if l:y - 2 > l:height
        " Fits above
        let l:y = winline() - l:height
      elseif l:y - 2 > &lines - l:y
        " Take space above cursor
        let l:y = 1
        let l:height = winline()-2
      else
        " Take space below cursor
        let l:height = &lines -l:y
      endif
    endif
    let l:col = col('.')
    " Positioning is not window but screen relative
    let l:opts = {
          \ 'relative': 'win',
          \ 'row': l:y,
          \ 'col': l:col,
          \ 'width': l:width,
          \ 'height': l:height,
          \ }
    return l:opts
endfunction

function! lsp#ui#vim#output#floatingpreview(data) abort
    let l:buf = nvim_create_buf(v:false, v:true)
    call setbufvar(l:buf, '&signcolumn', 'no')

    " Try to get as much pace right-bolow the cursor, but at least 10x10
    let l:width = max([float2nr(&columns - col('.') - 10), 10])
    let l:height = max([&lines - winline() + 1, 10])

    let l:opts = s:get_float_positioning(l:height, l:width)

    let s:win = nvim_open_win(buf, v:true, l:opts)
    call nvim_win_set_option(s:win, 'winhl', 'Normal:Pmenu,NormalNC:Pmenu')
    call nvim_win_set_option(s:win, 'foldenable', v:false)
    call nvim_win_set_option(s:win, 'wrap', v:true)
    call nvim_win_set_option(s:win, 'statusline', '')
    call nvim_win_set_option(s:win, 'number', v:false)
    call nvim_win_set_option(s:win, 'relativenumber', v:false)
    call nvim_win_set_option(s:win, 'cursorline', v:false)
    " Enable closing the preview with esc, but map only in the scratch buffer
    nmap <buffer><silent> <esc> :pclose<cr>
    return s:win
endfunction

function! lsp#ui#vim#output#preview(data) abort
    " Close any previously opened preview window
    pclose

    let l:current_window_id = win_getid()

    if s:supports_floating && g:lsp_preview_float
      call lsp#ui#vim#output#floatingpreview(a:data)
    else
      execute &previewheight.'new'
    endif
    let s:win = win_getid()

    let l:ft = s:append(a:data)
    " Delete first empty line
    0delete _

    setlocal readonly nomodifiable

    let &l:filetype = l:ft . '.lsp-hover'
    " Get size information while still having the buffer active
    let l:bufferlines = line('$')
    let l:maxwidth = max(map(getline(1, '$'), 'strdisplaywidth(v:val)'))

    if g:lsp_preview_keep_focus
      " restore focus to the previous window
      call win_gotoid(l:current_window_id)
    endif

    echo ''

    if s:supports_floating && s:win && g:lsp_preview_float
      let l:win_config = {}
      let l:height = min([winheight(s:win), l:bufferlines])
      let l:width = min([winwidth(s:win), l:maxwidth])
      let l:win_config = s:get_float_positioning(l:height, l:width)
      call nvim_win_set_config(s:win, l:win_config )
      augroup lsp_float_preview_close
        autocmd! lsp_float_preview_close CursorMoved,CursorMovedI,VimResized *
        autocmd CursorMoved,CursorMovedI,VimResized * call lsp#ui#vim#output#closepreview()
      augroup END
    endif
    return ''
endfunction

function! s:append(data) abort
    if type(a:data) == type([])
        for l:entry in a:data
            call s:append(entry)
        endfor

        return 'markdown'
    elseif type(a:data) == type('')
        silent put =a:data

        return 'markdown'
    elseif type(a:data) == type({}) && has_key(a:data, 'language')
        silent put ='```'.a:data.language
        silent put =a:data.value
        silent put ='```'

        return 'markdown'
    elseif type(a:data) == type({}) && has_key(a:data, 'kind')
        silent put =a:data.value

        return a:data.kind ==? 'plaintext' ? 'text' : a:data.kind
    endif
endfunction
