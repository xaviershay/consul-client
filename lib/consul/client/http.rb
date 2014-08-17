require 'net/http'
require 'json'
require 'logger'

module Consul
  module Client
    # Any non-successful response from Consul will result in this error being
    # thrown.
    ResponseException = Class.new(StandardError)

    # Low-level wrapper around consul HTTP api. Do not instantiate this class
    # directly, instead use the appropriate factory methods.
    #
    # @see Consul::Client::V1#http
    class HTTP
      # @api private
      def initialize(host:, port:, logger:)
        @host   = host
        @port   = port
        @logger = logger
      end

      # Get JSON data from an endpoint.
      #
      # @param request_uri [String] portion of the HTTP path after the version
      #                             base, such as +/agent/self+.
      # @return [Object] parsed JSON response
      # @raise [ResponseException] if non-200 response is received.
      def get(request_uri)
        url = base_uri + request_uri
        logger.debug("GET #{url}")

        uri = URI.parse(url)

        response = http_request(:get, uri)

        parse_body(response)
      end

      # Watch an endpoint until the value returned causes the block to evaluate
      # +false+.
      #
      # @param request_uri [String] portion of the HTTP path after the version
      #                             base, such as +/agent/self+.
      # @return [Object] parsed JSON response
      # @raise [ResponseException] if non-200 response is received.
      # @example blocks until there are at least 3 passing nodes for the web service.
      #     http.get_while("/health/service/web?passing") do |data|
      #       data.size <= 2
      #     end
      def get_while(request_uri, &block)
        url = base_uri + request_uri
        index = 0
        json = nil

        check = ->{
          uri = URI.parse(url)
          uri.query ||= ""
          uri.query += "&index=#{index}&wait=10s"
          logger.debug("GET #{uri}")

          response = http_request(:get, uri)
          index = response['x-consul-index'].to_i

          json = parse_body(response)

          block.(json)
        }

        while check.()
        end

        json
      end

      # Put request to an endpoint. If data is provided, it is JSON encoded and
      # sent in the request body.
      # @param request_uri [String] portion of the HTTP path after the version
      #                             base, such as +/agent/self+.
      # @param data        [Object] body for request
      # @return [Object] parsed JSON response
      # @raise [ResponseException] if non-200 response is received.
      def put(request_uri, data = nil)
        url = base_uri + request_uri
        logger.debug("PUT #{url}")

        uri = URI.parse(url)

        response = http_request(:put, uri, data)

        parse_body(response)
      end

      attr_accessor :logger

      protected

      def base_uri
        "http://#{@host}:#{@port}/v1"
      end

      def parse_body(response)
        JSON.parse("[#{response.body}]")[0]
      end

      def http_request(method, uri, data = nil)
        method = {
          get: Net::HTTP::Get,
          put: Net::HTTP::Put,
        }.fetch(method)

        http     = Net::HTTP.new(uri.host, uri.port)
        request  = method.new(uri.request_uri)
        request.body = data.to_json if data
        response = http.request(request)

        if response.code.to_i >= 400
          raise ResponseException, "#{response.code} on #{uri}"
        end

        response
      end
    end
  end
end
