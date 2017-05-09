module PuppetLanguageServer

  # TODO: Thread/Atomic safe? probably not
  class DocumentStore
    def set_document(uri,content)
      @documents[uri] = content
    end

    def remove_document(uri)
      @documents[uri] = nil
    end

    def document(uri)
      @documents[uri].clone
    end

    def initialize()
      @documents = {}
    end
  end

  class MessageRouter < JSONRPCHandler
    def initialize(*options)
      super(*options)
      @@documents = PuppetLanguageServer::DocumentStore.new()
    end

    def receive_request(request)
      case request.rpc_method
        when 'initialize'
          PuppetLanguageServer::LogMessage('debug','Received initialize method')
          request.reply_result( { 'capabilities' => PuppetLanguageServer::ServerCapabilites.capabilities} )
        when 'shutdown'
          PuppetLanguageServer::LogMessage('debug','Received shutdown method')
          request.reply_result(nil)
        else
          PuppetLanguageServer::LogMessage('error','Unknown RPC method #{request.rpc_method}')
      end
    end

    def receive_notification(method, params)
      case method
        when 'initialized'
          PuppetLanguageServer::LogMessage('information','Client has received initialization')
        when 'exit'
          PuppetLanguageServer::LogMessage('information','Received exit notification.  Shutting down.')
          EventMachine::stop_event_loop
        when 'textDocument/didOpen'
          PuppetLanguageServer::LogMessage('information','Received textDocument/didOpen notification.')
          file_uri = params['textDocument']['uri']
          content = params['textDocument']['text']
          @@documents.set_document(file_uri, content)
          reply_diagnostics(file_uri, PuppetLanguageServer::DocumentValidator.validate(content))
        when 'textDocument/didChange'
          PuppetLanguageServer::LogMessage('information','Received textDocument/didChange notification.')
          file_uri = params['textDocument']['uri']
          content = params['contentChanges'][0]['text'] # TODO: Bad
          @@documents.set_document(file_uri, content)
          reply_diagnostics(file_uri, PuppetLanguageServer::DocumentValidator.validate(content))
        when 'textDocument/didSave'
          PuppetLanguageServer::LogMessage('information','Received textDocument/didSave notification.')
        else
          PuppetLanguageServer::LogMessage('error',"Unknown RPC notification #{method}")
      end
    end
  end
end
