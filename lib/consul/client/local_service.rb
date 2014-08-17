module Consul
  module Client
    # Provides operations on services running on the local machine.
    class LocalService
      attr_reader :name, :consul

      def initialize(name, consul: Consul::Client.v1.http, logger: consul.logger)
        @name   = name
        @consul = consul
        consul.logger = logger
      end

      # Coordinate the shutdown of this node with the rest of the cluster so that
      # a minimum number of nodes is always healthy. Blocks until a shutdown lock
      # has been obtained and the cluster is healthy before yielding, in which
      # callers should mark the service unhealthy (but continue to accept
      # traffic). After the unhealthy state of the service has propagated and
      # `grace_period` seconds has passed, this method returns and the caller
      # should stop accepting new connections, finish existing work, then
      # terminate.
      def coordinated_shutdown!(min_nodes: 1, grace_period: 3, &block)
        cluster = Consul::Client.v1.service(name, consul: consul)

        cluster.lock("shutdown") do
          cluster.wait_until_healthy!(min_nodes: min_nodes)
          block.()
          wait_until_unhealthy!

          # Release lock here and perform shutdown in our own time, since we know
          # the consistent view of nodes does not include this one and so is safe
          # for other nodes to try restarting.
        end

        # Grace period for any in-flight connections on their way already
        # before health check failure propagated.
        #
        # No way to avoid a sleep here.
        Kernel.sleep grace_period
      end

      # Waits until the propagated health of this node is unhealthy so it is not
      # receiving new traffic.
      def wait_until_unhealthy!
        agent = consul.get("/agent/self")["Member"]["Name"]
        consul.get_while("/health/node/#{agent}") do |data|
          status = data.detect {|x| x["CheckID"] == "service:#{name}" }["Status"]
          status == 'passing'
        end
      end
    end
  end
end
