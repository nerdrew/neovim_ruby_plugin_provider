class NeovimPluginProvider::Request
  class << self
    attr_accessor :logger
  end

  attr_reader :id, :meth, :args

  def initialize(id, meth, args = [])
    @id = id
    @meth = meth
    @args = args
  end

  def type
    NeovimPluginProvider::REQUEST
  end

  def write_to(packer)
    self.class.logger.debug "writing request type=#{type} id=#{id} "\
      "error=#{error.inspect} result=#{result.inspect}"
    packer.write_array_header(4).
      write(type).
      write(id).
      write(meth).
      write(args)
    self.class.logger.debug "packer buffer=#{packer.to_a}"
    packer.flush
  end
end
