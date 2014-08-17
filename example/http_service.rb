# An HTTP server that restarts when a version file changes, while
# ensuring that a minimum number of nodes are healthy at all times.
#
# It is assumed that the server is running under a process manager that will
# restart it. This script itself just exits. For testing, a while loop
# suffices:
#
#     while true; do ruby http_service.rb; done
#
# For testing with multiple nodes in vagrant, using a version file on the
# shared file system is easiest. It will trigger restarts on all nodes at the
# same time.

MIN_NODES = 0
VERSION_FILE = File.expand_path(ARGV[0] || 'VERSION')

require 'logger'
require 'webrick'

require 'consul/client'

s = Consul::Client.v1.http
s.put("/agent/service/register",
  Name: 'http',
  Check: {
    Script: "curl --fail localhost:8000/_status >/dev/null 2>&1",
    Interval: "1s"
  }
)

$logger  = Logger.new($stdout)
$healthy = true

$logger.info "Monitoring #{VERSION_FILE} for changes"

server = WEBrick::HTTPServer.new \
  :Port => 8000

server.mount_proc '/' do |req, res|
  res.body = 'Hello, world!'
end

server.mount_proc '/long' do |req, res|
  sleep 1.5
  res.body = 'Hello, world!'
end

server.mount_proc '/_status' do |req, res|
  res.status = $healthy ? 200 : 503
end

def current_version
  File.read(VERSION_FILE)
end

initial = current_version
Thread.abort_on_exception = true
t = Thread.new do
  shutdown = false
  while !shutdown
    if initial != current_version
      c = Consul::Client.v1.local_service('http', logger: $logger)
      $logger.info "Obtaining shutdown lock"
      c.coordinated_shutdown!(min_nodes: MIN_NODES) do
        $logger.info "Obtained lock, marking unhealthy"
        $healthy = false
      end

      $logger.info "Unhealthy and grace period elapsed, gracefully terminating"

      server.shutdown

      $logger.info "Server is stopped, exiting"
      shutdown = true
    end
    sleep 1
  end
end

puts <<-BANNER

   ,~~.,''"'`'.~~.
  : {` .- _ -. '} ;
   `:   O(_)O   ;'
    ';  ._|_,  ;`   i am starting the server
     '`-.\\_/,.'`

BANNER

server.start
