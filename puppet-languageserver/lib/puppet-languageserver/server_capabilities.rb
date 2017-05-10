# https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#initialize-request

#require '../languageserver/languageserver'

module PuppetLanguageServer
  module ServerCapabilites
    def self.capabilities()
      # Specify the language server's capabilities
      # capabilities = {
      #   'textDocumentSync' => {
      #     'openClose?' => true,
      #     'change?'    => LanguageServer::TEXTDOCUMENTSYNCKIND_FULL,
      #     'willSave?'  => true,
      #     'willSaveWaitUntil?'  => true,
      #     'save?'  => true,
      #   },
      #   'completionProvider' => {
      #     'resolveProvider' => true,
      #   }
      # }

      {
        'textDocumentSync' => LanguageServer::TEXTDOCUMENTSYNCKIND_FULL,
        'hoverProvider' => true,
        'completionProvider' => {
          'resolveProvider' => true,
        }
      }
    end
  end
end
