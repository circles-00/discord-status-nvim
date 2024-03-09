local goProgramPID = nil
local host, port = "127.0.0.1", 8080
local TCPClient = require('nvim-discord-status.tcp_client')
local utils = require('nvim-discord-status.utils')
local setupOpts = require('nvim-discord-status')

local client = TCPClient:new()

vim.api.nvim_create_autocmd({ "VimEnter" }, {
  pattern = { "*" },
  callback = function()
    local script_path = utils.get_script_path()

    if (script_path == nil) then
      return
    end

    local path_to_script = utils.removeLastThreeParts(script_path)

    local absolute_path = "/" .. path_to_script .. "/" .. "go/discord_status > log.txt 2>&1 &"
    setupOpts.setup() -- TODO: Remove this
    local handle = io.popen(absolute_path .. "echo $!")

    if (handle == nil) then
      return
    end

    local pid = handle:read("*a")

    handle:close()

    goProgramPID = tonumber(pid)

    -- Wait for the TCP server to start
    utils.asyncSleep(1, function()
      client:connect(host, port)
      client:send("connect:" .. setupOpts.opts.discordAppId)
    end)
  end
})

vim.api.nvim_create_autocmd({ "BufEnter" }, {
  pattern = { "*" },
  callback = function()
    local filename = vim.fn.expand('%:p')
    local handle = io.popen("basename `git rev-parse --show-toplevel`")
    if (handle == nil) then
      return
    end

    local result = handle:read("*a")
    client:send(filename .. ":" .. result);

    handle:close()
  end
})

-- Cleanup the TCP client and the Go program
vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
  pattern = { "*" },
  callback = function()
    client:close()
    os.execute("kill " .. goProgramPID)
  end
})
