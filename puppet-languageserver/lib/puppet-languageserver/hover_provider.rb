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

      content = nil
      case item.class.to_s
        when "Puppet::Pops::Model::QualifiedName"
          if !item.eContainer.nil? && item.eContainer.class.to_s == "Puppet::Pops::Model::ResourceExpression"
            content = get_resource_expression_content(item.eContainer)
          elsif !item.eContainer.nil? && item.eContainer.class.to_s == "Puppet::Pops::Model::CallNamedFunctionExpression"
            content = get_call_named_function_expression_content(item.eContainer)
          # else
          #   require 'pry'; binding.pry
          #   puts ""
          end

        when "Puppet::Pops::Model::AttributeOperation"
          # Get the parent resource class
          parent_klass = item.eContainer
          while !parent_klass.nil? && parent_klass.class.to_s != "Puppet::Pops::Model::ResourceBody"
            parent_klass = parent_klass.eContainer
          end
          raise "Unable to find suitable parent object for object of type #{item.class.to_s}" if parent_klass.nil?

          # Instaniate an instance of the type
          item_type = Puppet::Type.type(parent_klass.eContainer.type_name.value)
          # Check if it's a property
          attribute = item_type.validproperty?(item.attribute_name)
          if attribute != false
            content = "**#{item.attribute_name}** Property\n\n"
            content = content + " (_required_)" if attribute.isrequired
            content = content + "\n" + attribute.doc.to_s + "\n"
          elsif item_type.validparameter?(item.attribute_name.intern)
            content = "**#{item.attribute_name}** Parameter"
          end

        else
          raise "Unable to generate Hover information for object of type #{item.class.to_s}"
      end

      if content.nil?
        LanguageServer::Hover.create_nil_response()
      else
        LanguageServer::Hover.create({
          'contents' => content,
        })
      end
    end

    # Content generation functions
    def self.get_call_named_function_expression_content(item)
      func_name = item.functor_expr.value
      raise "Function #{func_name} does not exist" if Puppet::Parser::Functions.function(func_name) == false

      function_module = Puppet::Parser::Functions.environment_module(Puppet.lookup(:current_environment))
      func_info = function_module.get_function_info(func_name.intern)
      raise "Function #{func_name} does not have information" if func_info.nil?

      # TODO: what about rvalue?
      content = "**#{func_name}**\n\n" # TODO: Do i add in the params from the arity number?
      content = content + func_info[:doc]

      content
    end

    def self.get_resource_expression_content(item)
      # Instaniate an instance of the type
      item_type = Puppet::Type.type(item.type_name.value)
      content = "**#{item.type_name.value}** Resource\n\n"
      # List out all attributes (Params + Props)
      attrs = []
      item_type.parameters.each { |param| attrs << param.to_s }
      item_type.properties.each do |prop|
        content = content + prop.name.to_s
        #(content = content + ' (_required_)') if prop.isrequired
        content = content + "\n\n"
      end
      attrs.sort.each { |attr| content = content + attr + "\n\n" }

      content
    end

  end
end
