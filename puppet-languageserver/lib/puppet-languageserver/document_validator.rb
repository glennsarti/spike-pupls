module PuppetLanguageServer

  module DocumentValidator
    def self.validate(content, max_problems = 100)
      result = []
      problems = 0

      # TODO: Should I wrap this thing in a big rescue block?
        Puppet[:code] = content
        env = Puppet.lookup(:current_environment)
        loaders = Puppet::Pops::Loaders.new(env)
        Puppet.override( {:loaders => loaders } , _('For puppet parser validate')) do
          begin
            validation_environment = nil ? env.override_with(:manifest => nil) : env
            validation_environment.check_for_reparse
            validation_environment.known_resource_types.clear
          rescue => detail
            unless detail.line.nil? || detail.pos.nil? || detail.basic_message.nil?
              result << LanguageServer::Diagnostic.create({
                'severity' => LanguageServer::DIAGNOSTICSEVERITY_ERROR,
                'fromline' => detail.line - 1,  # Line numbers from puppet are base 1
                'toline' => detail.line - 1,    # Line numbers from puppet are base 1
                'fromchar' => detail.pos - 1,   # Pos numbers from puppet are base 1
                'tochar' => detail.pos + 1 - 1, # Pos numbers from puppet are base 1
                'source' => 'Puppet',
                'message' => detail.basic_message,
              })
            end
          end
        end

      result
    end
  end
end
