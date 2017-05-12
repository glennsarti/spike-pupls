module PuppetLanguageServer
  module FacterHelper
    def self.reset
      Facter.reset
      @fact_hash = nil
    end

    def self.load_facts
      reset
      Facter.loadfacts
      @fact_hash = Facter.to_hash
    end

    def self.facts
      load_facts if @fact_hash.nil?
      @fact_hash
    end
  end
end
