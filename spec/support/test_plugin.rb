module TestPlugin
  include NeovimPluginProvider::Plugin

  rpc :boom do
    'boom'
  end
end
