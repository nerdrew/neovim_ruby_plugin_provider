require "neovim_plugin_provider/version"
require "neovim_plugin_provider/host"

module NeovimPluginProvider
  REQUEST  = 0 # [0, msgid, method, param]
  RESPONSE = 1 # [1, msgid, error, result]
  NOTIFY   = 2 # [2, method, param]

  NO_METHOD_ERROR = 0x01
  ARGUMENT_ERROR  = 0x02
end
