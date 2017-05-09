module PuppetLanguageServer
  class MessageRouter < JSONRPCHandler

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

    # # This method must be overriden in the user's inherited class.
    def receive_notification(method, params)
      case method
        when 'initialized'
          PuppetLanguageServer::LogMessage('information','Client has received initialization')
        when 'exit'
          PuppetLanguageServer::LogMessage('information','Received exit notification.  Shutting down.')
          EventMachine::stop_event_loop
        else
          PuppetLanguageServer::LogMessage('error',"Unknown RPC notification #{method}")
      end
    end
  end
end
