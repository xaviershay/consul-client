require 'json'
require 'base64'
require 'fileutils'
require 'logger'
require 'socket'

require 'consul/client'
require 'pp'

require_relative '../dropwizard_logger'

$stdout.sync = true
$logger  = DropwizardLogger.new('updater', $stdout)

# Bind an ephemeral port that consul can health check against.
server = TCPServer.new('127.0.0.1', 0)
port = server.addr[1]

# Register a service for this process so that our locks will be released on
# abort.
s = Consul::Client.v1.http
s.put("/agent/service/register",
  Name: 'testdrive-updater',
  Check: {
    Script: "nc -z localhost #{port}",
    Interval: "1s"
  }
)

VERSION_FILE = ENV['VFILE'] || "VERSION"
DOWN_FILE    = ENV['DFILE'] || 'down'

def current_version
  Net::HTTP.get(URI.parse("http://localhost:8000/_version")).chomp rescue nil
end

service_name = 'testdrive'
min_nodes = 1

current_spec = nil
new_spec = nil
loop do
  # Block until the spec changes
  s = Consul::Client.v1.http
  s.get_while("/kv/#{service_name}/spec") do |data|
    new_spec = data[0]["Value"]
    current_spec == new_spec
  end
  current_spec = new_spec

  # To avoid race conditions, only one agent can try to re-configure at a time.
  $logger.info "Detected version change, acquiring lock to restart"

  c = Consul::Client.v1.service(service_name + '-updater')
  c.lock("restart") do
    data = s.get("/kv/#{service_name}/spec")
    spec = JSON.parse(Base64.decode64(data[0]["Value"]))

    $logger.debug "checking if version change is needed"

    # This logic is pretty janky, it basically figures out a split of servers
    # such that it can optimally handle the expected traffic split, while
    # maintaining a minimum number of servers per version. This latter feature
    # enables you to do "fast shifts" if you have sufficient capacity, say if
    # you encounter a bug during a rollout and need to slam all traffic from
    # one version to another.
    actual  = {}
    desired = {}

    me = s.get("/agent/self")["Member"]["Name"]

    spec.each do |version, ratio|
      desired[version] = min_nodes
      actual[version] =
        s.get("/health/service/#{service_name}?passing&tag=#{version}")
          .reject {|x| x['Node']['Node'] == me }
          .size
    end

    total  = actual.values.reduce(:+) + 1
    tokens = [true] * [total - min_nodes * actual.size, 1].max

    spec.each do |version, ratio|
      extra = (ratio * total.to_f).round - min_nodes
      desired[version] += tokens.shift(extra).size if extra > 0
    end

    $logger.debug "actual:  " + actual.pretty_inspect
    $logger.debug "desired: " + desired.pretty_inspect
    x = desired.to_a.sort_by {|version, n|
      actual[version] - n
    }
    desired_version = x[0][0]

    if current_version != desired_version
      $logger.info "Acquired lock, shutting down service"
      FileUtils.touch(DOWN_FILE)

      begin
        # This is the most reliable way of detecing the service is down, bind
        # to the port and wait for it to be closed.
        socket = TCPSocket.open('localhost', 8000)
        socket.read
      rescue Errno::ECONNRESET, Errno::ECONNREFUSED => e
        nil
      end

      # In reality, this would probably be flipping a symlink to a different
      # version of code.
      $logger.info "Service down, switching to new version"
      File.write(VERSION_FILE, desired_version)
      $logger.info "Removing down file"
      FileUtils.rm(DOWN_FILE)
    else
      $logger.info "Already correct version, skipping restart"
    end
  end
end
