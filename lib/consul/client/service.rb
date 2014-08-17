module Consul
  module Client
    # Provides cluster coordination features.
    class Service
      attr_reader :consul

      def initialize(name, consul: Consul::Client.v1)
        @name   = name
        @consul = consul
      end

      # Creates a session tied to this cluster, then blocks until the requested
      # lock can be acquired, then yields. The lock is released and the session
      # destroyed when the block completes.
      def lock(key, &block)
        session = consul.put("/session/create",
          LockDelay: '5s',
          Checks:    ["service:#{name}", "serfHealth"]
        )["ID"]
        loop do
          locked = consul.put("/kv/#{name}/#{key}?acquire=#{session}")

          if locked
            begin
              block.call
            ensure
              consul.put("/kv/#{name}/#{key}?release=#{session}")
              consul.put("/session/destroy/#{session}")
            end
            return
          else
            consul.get_while("/kv/#{name}/#{key}") do |body|
              body[0]["Session"]
            end
          end
          # TODO: Figure out why long poll doesn't work.
          # https://gist.github.com/xaviershay/30128b968bde0e2d3e0b/edit
          sleep 1
        end
      end

      # A cluster is healthy if it has N+1 nodes available. The extra 1 is assuming
      # that whoever is asking for this is about to terminate.
      def wait_until_healthy!(min_nodes: 1)
        consul.get_while("/health/service/#{name}?passing") do |data|
          data.size <= min_nodes
        end
      end

      attr_reader :name
    end
  end
end
