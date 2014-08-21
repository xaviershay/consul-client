module Consul
  module Client
    # Provides cluster coordination features. Do not instantiate this class
    # directly, instead use the appropriate factory methods.
    #
    # @see Consul::Client::V1#service
    class Service
      # @api private
      def initialize(name, consul: Consul::Client.v1.http)
        @name   = name
        @consul = consul
      end

      # Creates a session tied to this cluster, then blocks indefinitely until
      # the requested lock can be acquired, then yields. The lock is released
      # and the session destroyed when the block completes.
      #
      # @param key [String] the name of the lock to acquire. This is namespace
      #           under the service name and stored directly in the KV store,
      #           so make sure it does not conflict with other names. For
      #           instance, the leader lock for the +web+ service would be
      #           stored at +/kv/web/leader+.
      def lock(key, checks: ["service:#{name}"], &block)
        session = consul.put("/session/create",
          LockDelay: '3s',
          Checks:    ["serfHealth"] + checks
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
          sleep 3
        end
      end

      # Block indefinitely until the cluster is healthy.
      #
      # @param min_nodes [Integer] minimum number of nodes required to be
      #           healthy for the cluster as a whole to be considered healthy.
      #           This method will block until there is at least one more than
      #           this number, assuming that the caller is about to terminate.
      def wait_until_healthy!(min_nodes: 1)
        consul.get_while("/health/service/#{name}?passing") do |data|
          data.size <= min_nodes
        end
      end

      private

      attr_reader :name
      attr_reader :consul
    end
  end
end
