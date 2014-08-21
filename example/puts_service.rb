# Restart a cluster, ensuring that at a minimum number of nodes are healthy at
# all times.
#
# Run this on multiple Consul nodes, then ctrl-c them all and see what happens.

MIN_NODES = 0
DOWN_FILE = File.expand_path("../down", __FILE__)

require 'fileutils'
require 'consul/client'

require_relative './dropwizard_logger'

FileUtils.touch(DOWN_FILE)

s = Consul::Client.v1.http
s.put("/agent/service/register",
  Name: 'puts',
  Check: {
    Script: "test ! -e #{DOWN_FILE}",
    Interval: "1s"
  }
)

$shutdown = false
$logger = DropwizardLogger.new($stdout, 'puts')
$server = Thread.new do
  while !$shutdown
    $logger.info "Service is #{File.exist?(DOWN_FILE) ? "un" : ""}healthy"
    sleep 0.5
  end
end

shutdown_queue = Queue.new

shutdown = Thread.new do
  # Block until a shutdown is triggered.
  shutdown_queue.pop

  s = Consul::Client.v1.local_service("puts", logger: $logger)

  $logger.info "Obtaining shutdown lock"
  s.coordinated_shutdown!(min_nodes: MIN_NODES) do
    $logger.info "Obtained lock, marking unhealthy"
    FileUtils.touch(DOWN_FILE)
  end
  $logger.info "Unhealthy and grace period elapsed, shutting down"
  $shutdown = true
end

$int = false
trap 'INT' do
  if $int
    # Can't use logger in signal handlers
    $stderr.puts  "Interrupted while shutting down, terminating"
    exit 1
  end

  # Signal a shutdown to begin. Don't do it here because we need to stay
  # responsive to other signals.
  shutdown_queue << true
  $int = true
end

FileUtils.rm_rf(DOWN_FILE)

$server.value
