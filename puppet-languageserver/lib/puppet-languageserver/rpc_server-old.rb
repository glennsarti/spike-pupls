# https://raw.githubusercontent.com/ibc/em-jsonrpc/master/lib/em-jsonrpc/server.rb
require 'eventmachine'
#require 'yajl'
require 'json'

module PuppetLanguageServer
  class JSONRPCHandler < EM::Connection
    attr_reader :encoder

    def initialize(*options)
      parser_options = options.first || {}

      if parser_options[:symbolize_keys]
        @key_jsonrpc = :jsonrpc
        @key_id = :id
        @key_method = :method
        @key_params = :params
      else
        @key_jsonrpc = KEY_JSONRPC
        @key_id = KEY_ID
        @key_method = KEY_METHOD
        @key_params = KEY_PARAMS
      end

      # @parser = JSON::Parser.new parser_options
      # @parser.on_parse_complete = method(:received_parsed_object)

      @state = :data
    end

    def post_init
      PuppetLanguageServer::LogMessage('information','Client has connected to the language server')
    end

    def unbind
      PuppetLanguageServer::LogMessage('information','Client has disconnected to the language server')
    end

    def receive_data(data)
require 'pp'
x = pp(data)
puts x
puts "--- INBOUND\n#{data}\n---"
      case @state
      when :data
        message = extract_message(data)
        parse_data(message[:content])
      when :ignore
        nil
      end
    end

    def extract_message(data)
      message = { :header => {}, :content => nil }

      # Reference - https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#base-protocol
      raw_header, message[:content] = data.split("\r\n\r\n",2)

      # Extract the headers
      # Reference - https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#header-part
      raw_header.split("\r\n").each do |item|
        name, value = item.split(":",2)

        case
          when name.casecmp("Content-Length").zero?
            message[:header]['Content-Length'] = value.strip.to_i
          when name.casecmp("Content-Type").zero?
            message[:header]['Content-Length'] = value.strip
        else
          raise("Unknown header #{name} in Language Server message")
        end
      end

      # TODO: compare content-length and verify message is intact
      # TODO: encoding the message with the appropriate content-type
      message
    end

    def send_response(response)
      size = response.bytesize if response.respond_to?(:bytesize)
puts "--- OUTBOUND\n#{response}\n---"
      send_data "Content-Length: #{size}\r\n\r\n" + response
    end

    def parse_data(data)
      result = JSON.parse(data)

      received_parsed_object(result)
      # begin
      #   @parser << data
      # rescue Yajl::ParseError => e
      #   send_response PARSING_ERROR_RESPONSE
      #   close_connection_after_writing
      #   @state = :ignore
      #   parsing_error data, e
      # end
    end

    # Seperate method so async JSON parsing can be supported.
    def received_parsed_object(obj)

      #@encoder ||= Yajl::Encoder.new

      case obj
      # Individual request/notification.
      when Hash
        process(obj)
      # Batch: multiple requests/notifications in an array.
      # NOTE: Not implemented as it doesn't make sense using JSON RPC over pure TCP / UnixSocket.
      when Array
        send_response BATCH_NOT_SUPPORTED_RESPONSE
        close_connection_after_writing
        @state = :ignore
        batch_not_supported_error obj
      end
    end

    def process(obj)
      is_request = obj.has_key?(@key_id)
      id = obj[@key_id]
      if is_request
        unless id.is_a? String or id.is_a? Fixnum or id.is_a? NilClass
          invalid_request obj, CODE_INVALID_REQUEST, MSG_INVALID_REQ_ID
          reply_error nil, CODE_INVALID_REQUEST, MSG_INVALID_REQ_ID
          return false
        end
      end

      unless obj[@key_jsonrpc] == "2.0"
        invalid_request obj, CODE_INVALID_REQUEST, MSG_INVALID_REQ_JSONRPC
        reply_error id, CODE_INVALID_REQUEST, MSG_INVALID_REQ_JSONRPC
        return false
      end

      unless (method = obj[@key_method]).is_a? String
        invalid_request obj, CODE_INVALID_REQUEST, MSG_INVALID_REQ_METHOD
        reply_error id, CODE_INVALID_REQUEST, MSG_INVALID_REQ_METHOD
        return false
      end

      if (params = obj[@key_params])
        unless params.is_a? Array or params.is_a? Hash
          invalid_request obj, CODE_INVALID_REQUEST, MSG_INVALID_REQ_PARAMS
          reply_error id, CODE_INVALID_REQUEST, MSG_INVALID_REQ_PARAMS
          return false
        end
      end

      if is_request
        receive_request Request.new(self, id, method, params)
      else
        receive_notification method, params
      end
    end

    # This method must be overriden in the user's inherited class.
    def receive_request(request)
      puts "request received:\n#{request.inspect}"
    end

    # This method must be overriden in the user's inherited class.
    def receive_notification(method, params)
      puts "notification received (method: #{method.inspect}, params: #{params.inspect})"
    end

    def encode_json(data)
      #@encoder.encode(data)
      JSON.generate(data)
    end

    def reply_error(id, code, message)
      send_response encode_json({
        KEY_JSONRPC => VALUE_VERSION,
        KEY_ID => id,
        KEY_ERROR => {
          KEY_CODE => code,
          KEY_MESSAGE => message
        }
      })
    end

    # This method could be overriden in the user's inherited class.
    def parsing_error(data, exception)
      $stderr.puts "parsing error:\n#{exception.message}"
    end

    # This method could be overriden in the user's inherited class.
    def batch_not_supported_error(obj)
      $stderr.puts "batch request received but not implemented"
    end

    # This method could be overriden in the user's inherited class.
    def invalid_request(obj, code, message=nil)
      $stderr.puts "error #{code}: #{message}"
    end


    class Request
      attr_reader :rpc_method, :params, :id

      def initialize(conn, id, rpc_method, params)
        @conn = conn
        @id = id
        @rpc_method = rpc_method
        @params = params
      end

      def reply_result(result)
        return nil if @conn.error?

        response = {
          KEY_JSONRPC => VALUE_VERSION,
          KEY_ID => @id,
          KEY_RESULT => result
        }

        @conn.send_response(@conn.encode_json(response))
        return true

        # Send the response in chunks (good in case of a big response).
        # begin
        #   @conn.encode_json(response) do |chunk|
        #     @conn.send_response(chunk)
        #   end
        #   return true
        # rescue Yajl::EncodeError => e
        #   reply_internal_error "response encode error: #{e.message}"
        #   return false
        # end
      end

      def reply_internal_error(message=nil)
        return nil if @conn.error?
        @conn.reply_error(@id, CODE_INTERNAL_ERROR, message || MSG_INTERNAL_ERROR)
      end

      def reply_method_not_found(message=nil)
        return nil if @conn.error?
        @conn.reply_error(@id, CODE_METHOD_NOT_FOUND, message || MSG_METHOD_NOT_FOUND)
      end

      def reply_invalid_params(message=nil)
        return nil if @conn.error?
        @conn.reply_error(@id, CODE_INVALID_PARAMS, message || MSG_INVALID_PARAMS)
      end

      def reply_custom_error(code, message)
        return nil if @conn.error?
        unless code.is_a? Integer and (-32099..-32000).include? code
          raise ArgumentError, "code must be an integer between -32099 and -32000"
        end
        @conn.reply_error(@id, code, message)
      end
    end  # class Request

  end  # class Server


  def self.start_tcp_server(addr, port, handler, options=nil, &block)
    raise Error, "EventMachine is not running" unless EM.reactor_running?
    EM.start_server addr, port, handler, options, &block
  end

  def self.start_unix_domain_server(filename, handler, options=nil, &block)
    raise Error, "EventMachine is not running" unless EM.reactor_running?
    EM.start_unix_domain_server filename, handler, options, &block
  end

end