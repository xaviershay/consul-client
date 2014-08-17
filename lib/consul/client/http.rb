require 'net/http'
require 'json'
require 'logger'

module Consul
  module Client
    ResponseException = Class.new(StandardError)

    # Low-level wrapper around consul HTTP api.
    class HTTP
      def self.v1(*args)
        new(*args)
      end

      def get(request_uri)
        url = base_uri + request_uri
        logger.debug("GET #{url}")

        uri = URI.parse(url)

        response = http_request(:get, uri)

        parse_body(response)
      end

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

      def put(request_uri, data = nil)
        url = base_uri + request_uri
        logger.debug("PUT #{url}")

        uri = URI.parse(url)

        response = http_request(:put, uri, data)

        parse_body(response)
      end

      attr_accessor :logger

      protected

      def initialize(
        host:   "localhost",
        port:   8500,
        logger: Logger.new("/dev/null")
      )

        @host   = host
        @port   = port
        @logger = logger
      end

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
