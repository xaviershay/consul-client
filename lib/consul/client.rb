require 'consul/client/local_service'
require 'consul/client/service'
require 'consul/client/http'

require 'logger'

# Top-level Consul name space.
module Consul
  # Top-level client name space. All public entry points are via this module.
  module Client
    # Default logger that silences all diagnostic output.
    NULL_LOGGER = Logger.new("/dev/null")

    # Provides builders that support V1 of the Consul HTTP API.
    # @return [Consul::Client::V1]
    def self.v1
      V1.new
    end

    # Do not instantiate this class directly.
    #
    # @see Consul::Client.v1
    class V1
      # Returns high-level local service utility functions.
      #
      # @param name [String] name of the service. Must match service ID in
      #                        Consul.
      # @param http [Consul::Client::HTTP] http client to use.
      # @param logger [Logger] logger for diagnostic information.
      # @return [Consul::Client::LocalService]
      # @example
      #     local = Consul::Client.v1.local_service('web')
      #     local.coordinated_shutdown! { $healthy = false }
      def local_service(name, http:Consul::Client.v1.http, logger:http.logger)
        LocalService.new(name, http: http, logger: logger)
      end

      # Returns high-level service utility functions.
      #
      # @example
      #     service = Consul::Client.v1.service('web')
      #     service.lock('leader') { puts "I am the cluster leader!" }
      def service(*args)
        Service.new(*args)
      end

      # Returns a thin wrapper around the Consult HTTP API.
      #
      # @param host [String] host of Consul agent.
      # @param port [Integer] port to connect to Consul agent.
      # @param logger [Logger] logger for diagnostic information.
      # @return [Consul::Client::HTTP]
      # @example
      #     http = Consul::Client.v1.http(logger: Logger.new($stdout))
      #     puts http.get("/get/self")["Member"]["Name"]
      def http(host: "localhost", port: 8500, logger: NULL_LOGGER)
        HTTP.new(host: host, port: port, logger: logger)
      end
    end
  end
end
