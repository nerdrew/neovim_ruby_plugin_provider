module NeovimPluginProvider::Plugin
  def self.included(plugin)
    NeovimPluginProvider::Host.register(plugin)

    plugin.module_eval do
      def self.rpcs; @rpcs; end
      def self.specs; @specs; end

      def self.rpc(name, specs = {}, &block)
        fail ArgumentError, "unknown option(s)=#{specs.inspect}" unless (specs.keys - %i(sync)).empty?
        @rpcs ||= {}
        @specs ||= {}
        @rpcs[name.to_s] = block
        @specs[name.to_s] = specs
      end
    end
  end
end
