# cmp-browser-source

Browser source for [nvim-cmp](https://github.com/hrsh7th/nvim-cmp). (Inspired by [coc-browser](https://github.com/voldikss/coc-browser))

# Install

1. Install Chrome extension from [Chrome Store](https://chrome.google.com/webstore/detail/completion-source-provide/dgfnehmpeggdlmbblgjfbfioegibajlb). ([source code](https://github.com/meetcw/browser-completion-source-provider))

2. Install this plugin by Packer or Plug.

# Setup

``` lua


require('cmp-browser-source').start_server()

require'cmp'.setup {
    -- other config
    sources = cmp.config.sources({
        -- other source
        { name = 'browser' },
        -- other source
    }),
    -- other config
}
```
