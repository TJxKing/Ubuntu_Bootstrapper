" ── General ───────────────────────────────────────────────────────────────────
set nocompatible
syntax on
set encoding=utf-8
set fileencoding=utf-8

" ── UI ───────────────────────────────────────────────────────────────────────
set number
set relativenumber
set cursorline
set showmatch
set showcmd
set wildmenu
set wildmode=longest:full,full
set laststatus=2
set ruler
set scrolloff=8
set signcolumn=yes

" ── Search ───────────────────────────────────────────────────────────────────
set hlsearch
set incsearch
set ignorecase
set smartcase

" ── Indentation ──────────────────────────────────────────────────────────────
set autoindent
set smartindent
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4

" ── Behavior ─────────────────────────────────────────────────────────────────
set backspace=indent,eol,start
set mouse=a
set clipboard=unnamedplus
set hidden
set noswapfile
set nobackup
set undofile
set undodir=~/.vim/undodir

" ── Splits ───────────────────────────────────────────────────────────────────
set splitbelow
set splitright

" ── Key mappings ─────────────────────────────────────────────────────────────
" Clear search highlight with Escape
nnoremap <Esc> :nohlsearch<CR>

" Move between splits with Ctrl+hjkl
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Create undo directory if it doesn't exist
if !isdirectory(expand("~/.vim/undodir"))
    call mkdir(expand("~/.vim/undodir"), "p")
endif
