# https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#initialize-request

#require '../languageserver/languageserver'

module PuppetLanguageServer
  module ServerCapabilites
    def self.capabilities()
      {
        'textDocumentSync' => LanguageServer::TEXTDOCUMENTSYNCKIND_FULL,
        'hoverProvider' => true,
        'completionProvider' => {
          'resolveProvider' => true,
          'triggerCharacters' => ['>','$','[']
        }
      }
    end
  end
end
