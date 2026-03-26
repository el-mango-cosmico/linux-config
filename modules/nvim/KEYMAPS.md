# Neovim / LazyVim Keymap Reference

`<leader>` = **Space**
`<C-x>` = Ctrl+x
`<S-x>` = Shift+x

---

## Navigation

| Key | Action |
|-----|--------|
| `<leader><space>` | Find files |
| `<leader>/` | Search in current file |
| `<leader>sg` | Live grep (search all files) |
| `<leader>sb` | Search open buffers |
| `<leader>e` | Toggle file explorer |
| `<leader>E` | Focus file explorer |
| `H` / `L` | Previous / next buffer |
| `<C-h/j/k/l>` | Move between splits |
| `gg` / `G` | Top / bottom of file |
| `<C-d>` / `<C-u>` | Scroll half-page down/up |
| `%` | Jump to matching bracket |

---

## Editing

| Key | Action |
|-----|--------|
| `<leader>cf` | Format file |
| `gcc` | Toggle comment (line) |
| `gc` (visual) | Toggle comment (selection) |
| `s` | Flash jump (type letters to jump anywhere) |
| `<leader>sr` | Search & replace |
| `u` / `<C-r>` | Undo / redo |
| `>` / `<` (visual) | Indent / dedent |

---

## LSP (code intelligence)

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | Go to references |
| `gI` | Go to implementation |
| `K` | Hover docs |
| `<leader>ca` | Code actions |
| `<leader>cr` | Rename symbol |
| `<leader>cd` | Show diagnostics (line) |
| `]d` / `[d` | Next / previous diagnostic |

---

## Git

| Key | Action |
|-----|--------|
| `<leader>gg` | Open Lazygit |
| `<leader>gb` | Git blame line |
| `]h` / `[h` | Next / previous hunk |
| `<leader>ghs` | Stage hunk |
| `<leader>ghr` | Reset hunk |

---

## Terminal & AI

| Key | Action |
|-----|--------|
| `<C-\>` | Toggle floating terminal |
| `<leader>tt` | Toggle floating terminal |
| `<leader>th` | Toggle horizontal terminal |
| `<leader>ai` | Open Claude Code CLI in terminal |
| `<leader>aa` | Avante: ask AI (needs API key) |
| `<leader>ae` | Avante: edit selection with AI |
| `<Esc><Esc>` | Exit terminal mode |

---

## Windows & Tabs

| Key | Action |
|-----|--------|
| `<leader>w` | Window commands (then `s`/`v`/`c` for split/vsplit/close) |
| `<leader>-` | Horizontal split |
| `<leader>\|` | Vertical split |
| `<leader>wd` | Close window |
| `<leader>bd` | Close buffer |
| `<leader>bo` | Close other buffers |

---

## Tips for Getting Started

1. Press `<Space>` and **wait** — which-key will show all available commands
2. `<Space>sk` searches all keymaps by name
3. `:Lazy` opens the plugin manager UI
4. `:Mason` opens the LSP/tool installer UI
5. `:LazyExtras` to browse optional LazyVim feature bundles
6. `<Space>l` for Lazy, `<Space>cm` for Mason shortcuts
