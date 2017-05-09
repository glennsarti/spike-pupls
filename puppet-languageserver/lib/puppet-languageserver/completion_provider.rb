module PuppetLanguageServer

  module CompletionProvider
    def self.complete(content, line_num, char_num)
      # TODO: CRLF vs LF?
      # Example validator from https://github.com/Microsoft/vscode-languageserver-node-example/blob/master/server/src/server.ts#L70
      items = []
      incomplete = false

      items << LanguageServer::CompletionItem.create({
        'label' => 'TypeScript',
        'kind'  => LanguageServer::COMPLETIONITEMKIND_TEXT,
        'data'  => 1,
      })
      items << LanguageServer::CompletionItem.create({
        'label' => 'JavaScript',
        'kind'  => LanguageServer::COMPLETIONITEMKIND_TEXT,
        'data'  => 2,
      })

      LanguageServer::CompletionList.create({
        'isIncomplete' => incomplete,
        'items'        => items,
      })
    end

    def self.resolve(label, kind, data)
      case data
        when 1
          LanguageServer::CompletionItem.create({
            'label' => label,
            'kind' => kind,
            'data' => 2,
            'detail' => 'TypeScript details',
            'documentation' => 'TypeScript documentation',
          })
        when 2
          LanguageServer::CompletionItem.create({
            'label' => label,
            'kind' => kind,
            'data' => 2,
            'detail' => 'JavaScript details',
            'documentation' => 'JavaScript documentation',
          })
      end
    end
  end
end
