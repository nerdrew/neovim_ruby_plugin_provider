require 'spec_helper'

describe NeovimPluginProvider do
  it "listens for msgpack rpcs on stdin and responds on stdout" do
    test_plugin = File.expand_path("../support/test_plugin.rb", __FILE__)
    stdin_r, stdin_w = IO.pipe
    stdout_r, stdout_w = IO.pipe
    host = NeovimPluginProvider::Host.new([test_plugin], verbose: true, stdin: stdin_r, stdout: stdout_w)

    host_thread = Thread.new do
      host.run
    end

    MessagePack.dump([NeovimPluginProvider::REQUEST, 1, 'poll', []], stdin_w)
    response = MessagePack.load(stdout_r)
    expect(response).to eq([1, 1, nil, "ok"])

    MessagePack.dump([NeovimPluginProvider::REQUEST, 2, 'poll', []], stdin_w)
    response = MessagePack.load(stdout_r)
    expect(response).to eq([NeovimPluginProvider::RESPONSE, 2, nil, "ok"])

    MessagePack.dump([NeovimPluginProvider::REQUEST, 3, 'specs', [test_plugin]], stdin_w)
    response = MessagePack.load(stdout_r)
    expect(response).to eq([NeovimPluginProvider::RESPONSE, 2, nil, "ok"])

    host.stop!
    host_thread.kill.join
  end
end
