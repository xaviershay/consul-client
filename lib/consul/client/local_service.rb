module Consul
  module Client
    # Provides operations on services running on the local machine. Do not
    # instantiate this class directly, instead use the appropriate factory
    # methods.
    #
    # @see Consul::Client::V1#local_service
    class LocalService
      # @api private
      def initialize(name, http:, logger:)
        @name   = name
        @consul = http
        @consul.logger = logger
      end

      # Coordinate the shutdown of this node with the rest of the cluster so
      # that a minimum number of nodes is always healthy. Blocks until a
      # shutdown lock has been obtained and the cluster is healthy before
      # yielding, in which callers should mark the service unhealthy (but
      # continue to accept traffic). After the unhealthy state of the service
      # has propagated and `grace_period` seconds has passed, this method
      # returns and the caller should stop accepting new connections, finish
      # existing work, then terminate.
      #
      # @param min_nodes [Integer] minimum require nodes for cluster to be
      #          considered healthy.
      # @param grace_period [Integer] number of seconds to sleep after service
      #          has been marked unhealthy in the cluster. This is important so
      #          that any in-flight requests are still able to be handled.
      def coordinated_shutdown!(min_nodes: 1, grace_period: 3, &block)
        cluster = Consul::Client.v1.service(name, consul: consul)

        cluster.lock("shutdown") do
          cluster.wait_until_healthy!(min_nodes: min_nodes)
          block.()
          wait_until_unhealthy!

          # Release lock here and perform shutdown in our own time, since we
          # know the consistent view of nodes does not include this one and so
          # is safe for other nodes to try restarting.
        end

        # Grace period for any in-flight connections on their way already
        # before health check failure propagated.
        #
        # No way to avoid a sleep here.
        Kernel.sleep grace_period
      end

      # Waits until the propagated health of this node is unhealthy so it is
      # not receiving new traffic.
      def wait_until_unhealthy!
        agent = consul.get("/agent/self")["Member"]["Name"]
        consul.get_while("/health/node/#{agent}") do |data|
          status = data.detect {|x| x["CheckID"] == "service:#{name}" }["Status"]
          status == 'passing'
        end
      end

      private

      attr_reader :name, :consul
    end
  end
end
