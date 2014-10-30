require 'webrick'

require 'consul/client'
require 'base64'

require_relative '../dropwizard_logger'

PORT = 8888

$logger  = DropwizardLogger.new('app', $stdout)
$healthy = true
$version = nil
$consul  = Consul::Client.v1.http(logger: $logger)

def start_with_latest_version
  # Here the service is down and is where you would symlink in latest version.
  # This demo doesn't just keeps the version in a global instead, since the
  # symlink part isn't relevant.

  # Ensure the service registration is present and has a tag matching the
  # version we are running. This will be present but unhealthy until the
  # service actually starts up.
  $version = Base64.decode64($consul.get("/kv/version")[0]['Value'])
  $consul.put("/agent/service/register",
    Name: 'http',
    Tags: [$version],
    Check: {
      Script: "curl --fail localhost:#{PORT}/_status > /dev/null 2>&1",
      Interval: "1s"
    }
  )

  # Clear restart flag
  node = $consul.get("/agent/self")["Member"]["Name"]
  $consul.put("/kv/nodes/#{node}/status", "up")

  # Start up with arbitrary sleep just for testing to simulate start up time.
  # "sv up"
  sleep 3
  $healthy = true
end

# Here we run a server in-process just for simplicity.
# In reality we would be monitoring a separate process.
server = WEBrick::HTTPServer.new \
  :Port   => PORT,
  :Logger => DropwizardLogger.new("webrick", $stdout).tap {|x|
              x.level = Logger::INFO
            },
  :AccessLog => [[$stdout, DropwizardLogger.webrick_format("webrick")]]

server.mount_proc '/_status' do |req, res|
  if $healthy
    $logger.info($version)
    res.status = 200
  else
    res.status = 503
  end
end

Thread.abort_on_exception = true
Thread.new do
  loop do
    # Block until restart flag is set
    node = $consul.get("/agent/self")["Member"]["Name"]
    $consul.get_while("/kv/nodes/#{node}/status") do |data|
      Base64.decode64(data[0]['Value']) != "down".to_json
    end

    # Trigger graceful shutdown. "sv down"
    $healthy = false

    # Wait until the consistent view of service membership excludes this node
    # before progressing. This is important to avoid a race condition loop
    # where we clear our restart flag and the coordinator sets it again because
    # it still thinks we're healthy.
    local = Consul::Client.v1.local_service("http", logger: $logger)
    local.wait_until_unhealthy!

    start_with_latest_version
  end
end

start_with_latest_version
server.start
