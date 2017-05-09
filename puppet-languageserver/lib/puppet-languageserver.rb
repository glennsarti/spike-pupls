require 'lib/languageserver/languageserver'

require 'lib/puppet-languageserver/rpc_constants'
require 'lib/puppet-languageserver/rpc_server'
require 'lib/puppet-languageserver/message_router'
require 'lib/puppet-languageserver/server_capabilities'
require 'lib/puppet-languageserver/document_validator'
require 'lib/puppet-languageserver/completion_provider'

require 'eventmachine'

module PuppetLanguageServer

  def self.LogMessage(severity, message)
    puts "[#{severity.upcase}] #{message}"
  end

  def self.RPCServer(args)
    EventMachine::run {
      EventMachine::start_server "127.0.0.1", 8081, PuppetLanguageServer::MessageRouter
      #EventMachine::start_server "127.0.0.1", 8081, EchoServer

      LogMessage('information','Language Server started.  Listening on port 8081')
    }
    LogMessage('information','Language Server exited.')
  end
end
