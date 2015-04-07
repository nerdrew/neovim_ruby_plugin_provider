require "neovim_plugin_provider/request"
require "neovim_plugin_provider/response"
require "neovim_plugin_provider/plugin"

require "socket"
require "msgpack"
require "logger"

class NeovimPluginProvider::Host
  @@mutex = Mutex.new

  def self.register(plugin)
    unless @@host
      fail 'no host initialized yet'
    end
    @@host.register(plugin)
  end

  def initialize(plugins = [], log: nil, verbose: false, stdin: STDIN, stdout: STDOUT)
    @logger = Logger.new(log || STDERR).tap { |l| l.level = verbose ? Logger::DEBUG : Logger::INFO }
    NeovimPluginProvider::Response.logger = @logger
    NeovimPluginProvider::Request.logger = @logger

    @logger.debug "starting plugins=#{plugins.inspect} "

    @@mutex.synchronize do
      @@host ||= self
      unless @@host == self
        @logger.error('Only one host allowed')
        fail 'Only one host allowed'
      end
    end

    @stdin = stdin
    @stdout = stdout
    @plugins = plugins.uniq
    @registered_plugins = {}
    @plugin_threads = []
    @request_queues = {}
    @write_queue = Queue.new
    @next_id = 0
    @next_id_mutex = Mutex.new
  end

  def run
    @packer = MessagePack::Packer.new(@stdout)
    @unpacker = MessagePack::Unpacker.new(@stdin)
    require_plugins
    start_write_thread
    start_listening
    #setup_neovim_config
  rescue => e
    @logger.error e.inspect
    @logger.error e.backtrace
  end

  def register(plugin)
    @registered_plugins[plugin.name] = plugin
    request_queue = Queue.new
    @request_queues[plugin.name] = request_queue
    @plugin_threads << start_plugin_thread(plugin, request_queue, @write_queue)
  end

  def stop!
    @logger.debug "Stopping plugin host"
    @io_r.close
    @io_w.close rescue IOError
    @write_thread.kill.join
    @plugin_threads.each(&:kill).each(&:join)
  end

  private

  def specs(name)
    plugin = @registered_plugins[name]
    unless plugin
      @logger.error "No spec for plugin='#{name}'; known specs=#{@registered_plugins.keys.inspect}"
      fail(ArgumentError, "No spec for plugin='#{name}'")
    end
    plugin.specs
  end

  def setup_neovim_config
    @logger.debug "Get vim_get_api_info from nvim"
    request = NeovimPluginProvider::Request.new(next_id, 'vim_get_api_info')
    request.write_to(@packer)
    _, id, err, result = @unpacker.unpack
    @logger.debug "id=#{id} err=#{err.inspect} result=#{result.inspect}"
    fail "request id mismatch on vim_get_api_info #{request.id} != #{id}" unless id == request.id
  rescue => e
    @logger.error "vim_get_api_info error=#{e.inspect}"
    @logger.error e.backtrace
  end

  def start_listening
    @logger.debug "Start listening for RPC calls"
    begin
      #loop do
        #type, id, rpc, args = @unpacker.unpack
      @unpacker.each do |type, id, rpc, args|
        @logger.debug "Received request type=#{type} id=#{id} rpc=#{rpc} args=#{args}"
        tmp = rpc.split('#', 2)
        meth = tmp.pop
        plugin = tmp.pop
        if type == NeovimPluginProvider::REQUEST
          handle_request(id, plugin, meth, args)
        else #elsif type == NeovimPluginProvider::RESPONSE
          @logger.warn "wtf type=#{type} id=#{id} rpc=#{rpc} args=#{args.inspect}"
        end
        @logger.debug "Request handled"
      end
      @logger.debug "stopped listening"
    rescue => e
      @logger.error e.inspect
      @logger.error e.backtrace
    end
  end

  def handle_request(id, plugin, meth, args)
    @logger.debug "handling request id=#{id} plugin=#{plugin.inspect} meth=#{meth.inspect} args=#{args.inspect}"
    unless plugin
      if meth == 'poll'
        response = NeovimPluginProvider::Response.new(id)
        response.result = 'ok'
        @write_queue.push(response)
      elsif meth == 'specs'
        response = NeovimPluginProvider::Response.new(id)
        response.result = args.map { |plugin_path| specs(plugin_path) }
      elsif meth == 'shutdown'
        stop!
      end
    else
      q = @request_queue[plugin] || fail(ArgumentError, "unknown plugin='#{plugin}'")
      q.push(NeovimPluginProvider::Request.new(id, meth, args))
    end
  rescue => e
    @logger.error e.inspect
    @logger.error e.backtrace
    response = NeovimPluginProvider::Response.new(id)
    response.error = e.inspect
    @write_queue.push(response)
  end

  def start_write_thread
    @logger.debug "Starting write thread"
    @write_thread = Thread.new do
      loop do
        begin
          @logger.debug "waiting for new outgoing message"
          @write_queue.pop.write_to(@packer)
        rescue => e
          @logger.error e.inspect
          @logger.error e.backtrace
        end
      end
    end
  end

  def require_plugins
    @plugins.each do |plugin|
      begin
        @logger.debug "requiring plugin=#{plugin}"
        require plugin
      rescue LoadError => e
        @logger.error e.inspect
        @logger.error e.backtrace
      rescue Exception => e
        @logger.error e.inspect
        @logger.error e.backtrace
      end
    end
  end

  def start_plugin_thread(plugin, request_queue, write_queue)
    Thread.new do
      loop do
        begin
          request = request_queue.pop
          response = NeovimPluginProvider::Response.new(request.id)
          meth = plugin.rpcs[request.meth] || fail(ArgumentError, "no rpc='#{request.meth}'")
          response.result = meth.call(*request.args)
        rescue => e
          response.error = e.inspect
          @logger.error e.inspect
          @logger.error e.backtrace
        ensure
          write_queue.push(response)
        end
      end
    end
  end

  def next_id
    @next_id_mutex.synchronize { @next_id += 1 }
  end
end
