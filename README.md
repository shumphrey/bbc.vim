📺 BBC.vim 📺
=============

Useful vim things for the BBC

- Completion functions for issues, users, projects, emojis

Completions
-----------

Vim provides many different completion tool.
See `:help ins-completion`

This plugin provides a completion function that can be used to complete:

- Jira projects
- Jira issues (matching `^project-\w*`)
- GitHub users (matching `^@\w*`)
- GitHub issues (matching `^#\w*`)
- Emojis (requires junegunn/emoji to be installed)

Completion of Jira issues is limited by Jira search functionality.

Completion of GitHub issues and users is limited to 100 results.
Typically search requires 2 or more characters typed.

Installation
------------

Requires vim8 or higher.

Depends on [vim-fugitive](https://github.com/tpope/vim-fugitive)
Install fugitive.vim then install this plugin the same way.

Depends on [vim-rhubarb](https://github.com/tpope/vim-rhubarb)
Set up curl and the GitHub access token as per Rhubarb's instructions.
Make sure your GitHub API token has sufficient permissions to read Org level repositories.

Emoji completion requires [junegunn/emoji](https://github.com/junegunn/vim-emoji)

To enable the completion function, add something like this to your vimrc:

```vim
let g:jira_domain = 'https://my.jira.domain'

augroup bbc
  au!
  au FileType gitcommit,markdown setlocal completefunc=bbc#complete
augroup END
```

Completion can now be triggered by doing \<ctrl-x\> \<ctrl-u\>
See `:help ins-completion` for more details.

Configuration
-------------

Add the following configuration to your ~/.vimrc or equivalent file:

Specify Jira domain, this is required:
```vim
let g:jira_domain = 'https://my.jira.domain'
```

Automatically set completion function for git commit messages:
```vim
augroup bbc
  au!
  au FileType gitcommit setlocal completefunc=bbc#complete
augroup END
```

See `help :completeopt` for ways to configure the completion menu.
e.g.

```vim
" Remove preview panel
set completeopt-=preview

" Make info pane a popup
set completeopt+=popup
```
