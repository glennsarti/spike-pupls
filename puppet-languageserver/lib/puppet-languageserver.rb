require 'languageserver/languageserver'

require 'puppet-languageserver/rpc_constants'
require 'puppet-languageserver/rpc_server'
require 'puppet-languageserver/message_router'
require 'puppet-languageserver/server_capabilities'
require 'puppet-languageserver/document_validator'
require 'puppet-languageserver/completion_provider'

require 'puppet'

module PuppetLanguageServer
  def self.LogMessage(severity, message)
    puts "[#{severity.upcase}] #{message}"
  end

  def self.RPCServer(args)
    LogMessage('information', "Using Puppet v#{Puppet::version}")
    EventMachine::run {
      EventMachine::start_server "127.0.0.1", 8081, PuppetLanguageServer::MessageRouter
      #EventMachine::start_server "127.0.0.1", 8081, EchoServer

      LogMessage('information','Language Server started.  Listening on port 8081')
    }
    LogMessage('information','Language Server exited.')
  end
end
