require 'consul/client'
require 'base64'

require_relative '../dropwizard_logger'

$logger  = DropwizardLogger.new('coordinator', $stdout)
$version = nil
$health  = nil
$queue   = Queue.new
$consul  = Consul::Client.v1.http(logger: $logger)

MIN_NODES = 1

Thread.abort_on_exception = true

# Watch for changes to required version
Thread.new do
  loop do
    v = nil
    $consul.get_while("/kv/version") do |data|
      v = Base64.decode64(data[0]['Value'])
      v == $version
    end
    $version = v

    $queue.push(true)
  end
end

# Watch for changes to session membership
Thread.new do
  loop do
    $health = $consul.get_while("/health/service/http") do |data|
      data == $health
    end

    $queue.push(true)
  end
end

# Loop everytime something changes.
while $queue.pop
  next unless $version && $health

  # Discard redundant updates.
  next if $queue.size > 0

  incorrect_nodes = $health.select {|x|
    !x['Service']['Tags'].include?($version)
  }
  $logger.info("#{$version}: #{incorrect_nodes.size} incorrect nodes")

  # If all nodes are running correct version, no action is necessary.
  next if incorrect_nodes.empty?

  healthy_nodes = $health.select {|x|
    x['Checks'].all? {|c| c['Status'] == 'passing' }
  }

  $logger.info("#{$version}: #{healthy_nodes.size} healthy nodes")
  restarting_nodes = $health.select {|x|
    node = x['Node']['Node']
    data = $consul.get("/kv/nodes/#{node}/status")
    Base64.decode64(data[0]['Value']) == "down".to_json
  }
  $logger.info("#{restarting_nodes.size} restarting nodes")

  # Exclude already restarting nodes from our calculations. We need to assume
  # that if they are not unhealthy already, they could become so at any moment.
  incorrect_nodes -= restarting_nodes
  healthy_nodes -= restarting_nodes

  $logger.info("#{$version}: #{incorrect_nodes.size} incorrect nodes minus restarting")
  $logger.info("#{$version}: #{healthy_nodes.size} healthy nodes minus restarting")

  # Ensure that there is always a minimum number of nodes in the cluster,
  # regardless of what version they are running. Per above, this calculation
  # excludes nodes that are already flagged for a restart.
  number_to_restart = healthy_nodes.size - MIN_NODES
  next unless number_to_restart > 0

  # Communicate to nodes that they are safe to restart. Individual nodes will
  # clear this flag on startup, even if it isn't healthy yet.
  $logger.info("#{$version}: #{number_to_restart} to restart")
  incorrect_nodes.take(number_to_restart).each do |x|
    node = x['Node']['Node']
    $consul.put("/kv/nodes/#{node}/status", "down")
  end
end
