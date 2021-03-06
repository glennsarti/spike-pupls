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

        when 'textDocument/completion'
          file_uri = request.params['textDocument']['uri']
          line_num = request.params['position']['line']
          char_num = request.params['position']['character']
          content = @@documents.document(file_uri)
          begin
            request.reply_result(PuppetLanguageServer::CompletionProvider.complete(content, line_num, char_num))
          rescue => exception
            PuppetLanguageServer::LogMessage('error',"(textDocument/completion) #{exception}")
            request.reply_result(LanguageServer::CompletionList.create_nil_response())
          end

        when 'completionItem/resolve'
          begin
            request.reply_result(PuppetLanguageServer::CompletionProvider.resolve(request.params.clone))
          rescue => exception
            PuppetLanguageServer::LogMessage('error',"(completionItem/resolve) #{exception}")
            # Spit back the same params if an error happens
            request.reply_result(request.params)
          end

        when 'textDocument/hover'
          file_uri = request.params['textDocument']['uri']
          line_num = request.params['position']['line']
          char_num = request.params['position']['character']
          content = @@documents.document(file_uri)
          begin
            request.reply_result(PuppetLanguageServer::HoverProvider.resolve(content, line_num, char_num))
          rescue => exception
            PuppetLanguageServer::LogMessage('error',"(textDocument/hover) #{exception}")
            request.reply_result(LanguageServer::Hover.create_nil_response())
          end
        else
          PuppetLanguageServer::LogMessage('error',"Unknown RPC method #{request.rpc_method}")
      end
    end

    def receive_notification(method, params)
      case method
        when 'initialized'
          PuppetLanguageServer::LogMessage('information','Client has received initialization')
          # DEBUG - Send a message with the Puppet version
          send_show_message_notification(3, "Using Puppet v#{Puppet::version}")

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
          content = params['contentChanges'][0]['text'] # TODO: Bad hardcoding zero
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
