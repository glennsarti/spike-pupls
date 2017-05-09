module PuppetLanguageServer

  module DocumentValidator
    def self.validate(content, max_problems = 100)
      # Example validator from https://github.com/Microsoft/vscode-languageserver-node-example/blob/master/server/src/server.ts#L70
      result = []

      problems = 0
      linenum = 0
      content.split(/\r?\n/).each do |line|
        prob_index = line.index('typescript')
        unless prob_index.nil?
          result << LanguageServer::Diagnostic.create({
            'severity' => LanguageServer::DIAGNOSTICSEVERITY_WARNING,
            'fromline' => linenum,
            'toline' => linenum,
            'fromchar' => prob_index,
            'tochar' => prob_index + 10,
            'source' => 'ex',
            'message' => "#{line.slice(prob_index, 10)} should be spelt TypeScript",
          })
        end
        linenum = linenum + 1
      end
      result
    end
  end
end
