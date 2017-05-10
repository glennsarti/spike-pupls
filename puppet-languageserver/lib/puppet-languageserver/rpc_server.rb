if ENV['NATIVE_EVENTMACHINE'].nil?
  require 'em/pure_ruby'
else
  require 'eventmachine'
end
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

      @state = :data
      @buffer = []
    end

    def post_init
      PuppetLanguageServer::LogMessage('information','Client has connected to the language server')
    end

    def unbind
      PuppetLanguageServer::LogMessage('information','Client has disconnected to the language server')
    end

    def extract_headers(raw_header)
      header = {}
      raw_header.split("\r\n").each do |item|
        name, value = item.split(":",2)

        case
          when name.casecmp("Content-Length").zero?
            header['Content-Length'] = value.strip.to_i
          when name.casecmp("Content-Type").zero?
            header['Content-Length'] = value.strip
        else
          raise("Unknown header #{name} in Language Server message")
        end
      end
      header
    end

    def receive_data(data)
      # Inspired by https://github.com/PowerShell/PowerShellEditorServices/blob/dba65155c38d3d9eeffae5f0358b5a3ad0215fac/src/PowerShellEditorServices.Protocol/MessageProtocol/MessageReader.cs
      return unless data.length > 0
      return if @state == :ignore

      # TODO: Thread/Atomic safe? probably not
      @buffer = @buffer + data.bytes.to_a

      while (@buffer.length > 4) do
        # Check if we have enough data for the headers
        # Need to find the first instance of '\r\n\r\n'
        offset = 0
        while (offset < @buffer.length - 4) do
          break if @buffer[offset] == 13
          offset = offset + 1
        end
        return unless (offset < @buffer.length - 4)

        # Extract the headers
        raw_header = @buffer.slice(0,offset).pack('C*').force_encoding('ASCII')  # Note the headers are always ASCII encoded
        headers = extract_headers(raw_header)
        raise("Missing Content-Length header") if headers['Content-Length'].nil?

        # Now we have the headers and the content length, do we have enough data now
        minimum_buf_length = offset + 3 + headers['Content-Length'] + 1  # Need to add one as we're converting from offset (zero based) to length (1 based) arrays
        return if @buffer.length < minimum_buf_length

        # Extract the message content
        content = @buffer.slice(offset + 3 + 1, headers['Content-Length']).pack('C*').force_encoding('utf-8') # TODO: default is utf-8.  Need to enode based on Content-Type
        # Purge the buffer
        @buffer = @buffer.slice(minimum_buf_length,@buffer.length - minimum_buf_length)
        @buffer = [] if @buffer.nil?

        parse_data(content)
      end
    end

    def send_response(response)
      size = response.bytesize if response.respond_to?(:bytesize)
puts "--- OUTBOUND\n#{response}\n---"
      send_data "Content-Length: #{size}\r\n\r\n" + response
    end

    def parse_data(data)
puts "--- INBOUND\n#{data}\n---"
      result = JSON.parse(data)
      received_parsed_object(result)
    end

    # Seperate method so async JSON parsing can be supported.
    def received_parsed_object(obj)
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

    def reply_diagnostics(uri, diagnostics)
      return nil if error?

      response = {
        KEY_JSONRPC => VALUE_VERSION,
        KEY_METHOD => 'textDocument/publishDiagnostics',
        KEY_PARAMS => { 'uri' => uri, 'diagnostics' => diagnostics}
      }

      send_response(encode_json(response))
      return true
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