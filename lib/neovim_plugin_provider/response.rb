class NeovimPluginProvider::Response
  class << self
    attr_accessor :logger
  end

  attr_reader :id
  attr_accessor :error, :result

  def initialize(id)
    @id = id
  end

  def type
    NeovimPluginProvider::RESPONSE
  end

  def write_to(packer)
    self.class.logger.debug "writing response type=#{type} id=#{id} "\
      "error=#{error.inspect} result=#{result.inspect}"
    packer.write_array_header(4).
      write(type).
      write(id).
      write(error).
      write(result)
    self.class.logger.debug "packer buffer=#{packer.to_a}"
    packer.flush
  end
end
