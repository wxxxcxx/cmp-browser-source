local cmp =  require('cmp')
local source = require('cmp-browser-source');

cmp.register_source('browser', source.new())
