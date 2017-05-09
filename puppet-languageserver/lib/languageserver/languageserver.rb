%w(constants diagnostic completion_list completion_item).each do |lib|
  begin
    require "languageserver/#{lib}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), lib))
  end
end
