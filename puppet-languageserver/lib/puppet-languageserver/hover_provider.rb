module PuppetLanguageServer

  module HoverProvider
    def self.resolve(content, line_num, char_num)
      # TODO: CRLF vs LF?
      # Example validator from https://github.com/Microsoft/vscode-languageserver-node-example/blob/master/server/src/server.ts#L70
      
      LanguageServer::Hover.create({
        'contents' => 'weeeeee',
      })
    end
  end
end
