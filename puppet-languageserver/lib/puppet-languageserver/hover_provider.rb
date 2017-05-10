module PuppetLanguageServer

  module HoverProvider
    def self.resolve(content, line_num, char_num)
      
      # Use Puppet to generate the AST
      parser = Puppet::Pops::Parser::Parser.new()
      result = parser.parse_string(content, '')

      # Convert line and char nums (base 0) to an absolute offset
      #   result.line_offsets contains an array of the offsets on a per line basis e.g.
      #     [0, 14, 34, 36]  means line number 2 starts at absolute offset 34
      #   Once we know the line offset, we can simply add on the char_num to get the absolute offset
      abs_offset = result.line_offsets[line_num] + char_num

      # Enumerate the AST looking for items that span the line/char we want.
      # Once we have all valid items, sort them by the smallest span.  Typically the smallest span
      # is the most specific object in the AST
      #
      # TODO: Should probably walk the AST and only look for the deepest child, but integer sorting
      #       is so much easier and faster.
      valid_models = result.model.eAllContents.select do |item|
        !item.offset.nil? && !item.length.nil? && abs_offset >= item.offset && abs_offset <= item.offset + item.length
      end.sort { |a, b| a.length - b.length }

      return LanguageServer::Hover.create_nil_response() if valid_models.length == 0
      item = valid_models[0]

      content = ''
      case item.class.to_s
        when "Puppet::Pops::Model::AttributeOperation"
          # Get the parent resource class
          parent_klass = item.eContainer
          while !parent_klass.nil? && parent_klass.class.to_s != "Puppet::Pops::Model::ResourceBody"
            parent_klass = parent_klass.eContainer
          end

          content = "attribute '#{item.attribute_name}' in class '#{parent_klass.eContainer.type_name.value}' with title '#{parent_klass.title.value}'"
        else
          raise "Unable to generate Hover information for object of type #{item.class.to_s}"
      end

      LanguageServer::Hover.create({
        'contents' => content,
      })
    end
  end
end
