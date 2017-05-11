module PuppetLanguageServer

  module PuppetParserHelper
    def self.object_under_cursor(content, line_num, char_num, try_char_removal = false)
      # Use Puppet to generate the AST
      parser = Puppet::Pops::Parser::Parser.new()

      result = nil
      begin
        result = parser.parse_string(content, '')
      rescue Puppet::ParseErrorWithIssue => exception
        raise unless try_char_removal

        # TODO: Do we care about CRLF vs LF - I don't think so.
        line_offset = 0
        (1..line_num).each { |_x| line_offset = content.index("\n",line_offset + 1) unless line_offset.nil? }
        raise if line_offset.nil?

        # Remove the offending character and try parsing again.
        new_content = content.slice(0,line_offset + char_num) + content.slice(line_offset + char_num + 1, content.length - 1)

        result = parser.parse_string(new_content, '')

#        puts line_offset
#require 'pry'; binding.pry
#        puts ""
      end

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

      return nil if valid_models.length == 0
      item = valid_models[0]

      item
    end
  end

  module CompletionProvider
    def self.complete(content, line_num, char_num)
      items = []
      incomplete = false

      item = PuppetLanguageServer::PuppetParserHelper.object_under_cursor(content, line_num, char_num, true)
      return LanguageServer::CompletionList.create_nil_response() if item.nil?

      case item.class.to_s
        when "Puppet::Pops::Model::ResourceExpression"
          # We are inside a resource definition.  Should display all available
          # properities and parameters.

          # TODO: Should really cache all of the resources and params/props for quick
          # searching and then only actually instatiate when needed.  For the moment,
          # instiate all the things!

          item_type = Puppet::Type.type(item.type_name.value)
          # Add Parameters
          item_type.parameters.each do |param|
            items << LanguageServer::CompletionItem.create({
              'label' => param.to_s,
              'kind'  => LanguageServer::COMPLETIONITEMKIND_PROPERTY,
              'detail' => 'Parameter',
              'data'  => { 'type' => 'resource_parameter',
                           'param' => param.to_s,
                           'resource_type' => item.type_name.value,
                         },
            })
          end
          # Add Properties
          item_type.properties.each do |prop|
            items << LanguageServer::CompletionItem.create({
              'label' => prop.name.to_s,
              'kind'  => LanguageServer::COMPLETIONITEMKIND_PROPERTY,
              'detail' => 'Property',
              'data'  => { 'type' => 'resource_property',
                           'prop' => prop.name.to_s,
                           'resource_type' => item.type_name.value,
                         },
            })
          end
      end

      LanguageServer::CompletionList.create({
        'isIncomplete' => incomplete,
        'items'        => items,
      })
    end

    def self.resolve(completion_item)
      data = completion_item['data'].clone
      case data['type']
        when 'resource_parameter'
          item_type = Puppet::Type.type(data['resource_type'])
          param_type = item_type.attrclass(data['param'].intern)
          # TODO: More things?
          completion_item['documentation'] = param_type.doc unless param_type.doc.nil?
          completion_item['insertText'] = "#{data['param']} => "
        when 'resource_property'
          item_type = Puppet::Type.type(data['resource_type'])
          prop_type = item_type.attrclass(data['prop'].intern)
          # TODO: More things?
          completion_item['documentation'] = prop_type.doc unless prop_type.doc.nil?
          completion_item['insertText'] = "#{data['prop']} => "
      end

      LanguageServer::CompletionItem.create(completion_item)
    end
  end
end
