require 'consul/client/local_service'
require 'consul/client/service'
require 'consul/client/http'

module Consul
  module Client
    # @public
    def self.v1
      V1.new
    end

    # Do not instantiate this class directly, use `Consul::Client.v1`
    #
    # @api private
    class V1
      # @public
      def local_service(*args)
        LocalService.new(*args)
      end

      # @public
      def service(*args)
        Service.new(*args)
      end

      # @public
      def http(*args)
        HTTP.new(*args)
      end
    end
  end
end
