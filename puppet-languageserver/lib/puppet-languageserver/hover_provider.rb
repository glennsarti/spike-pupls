module PuppetLanguageServer

  module HoverProvider
    def self.resolve(content, line_num, char_num)
      item = PuppetLanguageServer::PuppetParserHelper.object_under_cursor(content, line_num, char_num, false)
      return LanguageServer::Hover.create_nil_response() if item.nil?

      content = nil
      case item.class.to_s
        when "Puppet::Pops::Model::VariableExpression"
          expr = item.expr.value

          if expr == 'facts'
            # We are dealing with the facts variable
            # Just get the first part of the array and display that
            if item.eContainer.eContents.length > 1
              factname = item.eContainer.eContents[1].value
              content = get_fact_content(factname)
            end
          elsif expr.start_with?('::') && expr.rindex(':') == 1
            # We are dealing with a top local scope variable - Possible fact name
            factname = expr.slice(2,expr.length - 2)
            content = get_fact_content(factname)
          else
            # Could be a flatout fact name.  May not *shrugs.  That method of access is deprecated
            content = get_fact_content(expr)
          end
          puts ""

        when "Puppet::Pops::Model::QualifiedName"
          if !item.eContainer.nil? && item.eContainer.class.to_s == "Puppet::Pops::Model::ResourceExpression"
            content = get_resource_expression_content(item.eContainer)
          elsif !item.eContainer.nil? && item.eContainer.class.to_s == "Puppet::Pops::Model::CallNamedFunctionExpression"
            content = get_call_named_function_expression_content(item.eContainer)
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
            content = get_attribute_property_content(item_type, item.attribute_name.intern)
          elsif item_type.validparameter?(item.attribute_name.intern)
            content = get_attribute_parameter_content(item_type, item.attribute_name.intern)
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
    def self.get_fact_content(factname)
      return nil unless PuppetLanguageServer::FacterHelper.facts.has_key?(factname)
      value = PuppetLanguageServer::FacterHelper.facts[factname]
      content = "**#{factname}** Fact\n\n"
      
      if value.is_a?(Hash)
        content = content + "```\n" + JSON.pretty_generate(value) + "\n```"
      else
        content = content + value.to_s
      end

      content
    end

    def self.get_attribute_parameter_content(item_type, param)
      param_type = item_type.attrclass(param)
      content = "**#{param}** Parameter"
      content = content + "\n\n#{param_type.doc}" unless param_type.doc.nil?
      content
    end

    def self.get_attribute_property_content(item_type, property)
      prop_type = item_type.attrclass(property)
      content = "**#{property}** Property"
      content = content + "\n\n(_required_)" if prop_type.required?
      content = content + "\n\n#{prop_type.doc}" unless prop_type.doc.nil?
      content
    end

    def self.get_call_named_function_expression_content(item)
      func_name = item.functor_expr.value
      raise "Function #{func_name} does not exist" if Puppet::Parser::Functions.function(func_name) == false

      function_module = Puppet::Parser::Functions.environment_module(Puppet.lookup(:current_environment))
      func_info = function_module.get_function_info(func_name.intern)
      raise "Function #{func_name} does not have information" if func_info.nil?

      # TODO: what about rvalue?
      content = "**#{func_name}**\n\n" # TODO: Do I add in the params from the arity number?
      content = content + func_info[:doc]

      content
    end

    def self.get_resource_expression_content(item)
      # Instaniate an instance of the type
      item_type = Puppet::Type.type(item.type_name.value)
      content = "**#{item.type_name.value}** Resource\n\n"
      content = content + "\n\n#{item_type.doc}" unless item_type.doc.nil?
      content = content + "\n\n---\n"
      item_type.allattrs.sort.each { |attr|
        content = content + "* #{attr}\n"
      }

      content
    end

  end
end
