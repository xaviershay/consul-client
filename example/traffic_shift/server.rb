require 'logger'
require 'webrick'
require_relative '../dropwizard_logger'

require 'consul/client'

$stdout.sync = true

$logger  = DropwizardLogger.new('server', $stdout)
$healthy = true

PORT = 8000
DOWN_FILE = ENV['DFILE'] || 'down'
VERSION = File.read(ENV['VFILE'] || "VERSION").chomp rescue nil

unless VERSION
  sleep 1
  exit
end
$logger.info ("VERSION #{VERSION}")

s = Consul::Client.v1.http
s.put("/agent/service/register",
  Name: 'testdrive',
  Tags: [VERSION],
  Check: {
    Script: "curl --fail localhost:#{PORT}/_status >/dev/null 2>&1",
    Interval: "1s"
  }
)
if File.exist?(DOWN_FILE)
  $logger.info "#{DOWN_FILE} exists, sleeping for 1s before exit"
  sleep 1
  exit
end

server = WEBrick::HTTPServer.new \
  :Port      => PORT,
  :Logger    => DropwizardLogger.new("webrick", $stdout).tap {|x|
                  x.level = Logger::INFO
                },
  :AccessLog => [[$stdout, DropwizardLogger.webrick_format("webrick")]]

server.mount_proc '/_version' do |req, res|
  res.body = VERSION
end

server.mount_proc '/_status' do |req, res|
  $logger.debug VERSION
  res.status = $healthy ? 200 : 503
end

shutdown = Queue.new
Thread.abort_on_exception = true
t = Thread.new do
  shutdown.pop
  $logger.info "Commencing shutdown"

  # Simple graceful shutdown.
  $healthy = false
  s = Consul::Client.v1.local_service('testdrive')
  s.wait_until_unhealthy!

  # Grace period
  sleep 1

  server.shutdown
end

Thread.new do
  while !File.exist?(DOWN_FILE) do
    sleep 1
  end
  shutdown << true
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
  shutdown << true
  $int = true
end

server.start
$logger.info "Server is stopped, exiting"
