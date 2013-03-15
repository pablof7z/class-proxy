# This module provides a primitive for data models to establish a main
# data source (as a cache or for any data conversion/merging operation)
module ClassProxy
  extend ActiveSupport::Concern

  class NotFound < StandardError; end

  module ClassMethods
    # This method establishes how the cache should be hit, it receives a
    # hash with the data used for the query. If this method doesn't find
    # anything the fallbacks will be triggered
    #
    # @example Use with Active Record
    #   model.primary_fetch { |query| where(query).first }
    def primary_fetch(&block); @primary_fetch = block; end

    # Method used as fallback when the cache misses a hit fetch
    #
    # @example Using Github API for queries
    #   class GithubUser
    #     include ClassProxy
    #
    #     fallback_fetch { |args| Octokit.user(args[:login]) }
    #   end
    def fallback_fetch(&block); @fallback_fetch = block; end

    # Method that post-processes fallbacks, useful to reconvert data
    # from a fallback format into the model format
    #
    # @example Store Github API name in a different attribute
    #   class GithubUser
    #     include ClassProxy
    #
    #     fallback_fetch { |args| Octokit.user(args[:login]) }
    #     after_fallback_fetch do |obj|
    #       # obj is what `fallback_fetch` returns
    #       self.name  = obj.name
    #       self.login = obj.login
    #     end
    #
    #     attr_accessor :name, :login
    #   end
    def after_fallback_fetch(&block); @after_fallback_method = block; end

    # Establish attributes to proxy along with an alternative proc of how
    # the attribute should be loaded
    #
    # @example Load method using uppercase
    #   class GithubUser
    #     include ClassProxy
    #
    #     fallback_fetch { |args| Octokit.user(args[:login]) }
    #     after_fallback_fetch { |obj| self.name = obj.name; self.login = obj.login }
    #
    #     attr_accessor :name, :followers :login
    #
    #     proxy_methods :name, :followers, uppercase_login: lambda { login.upcase }
    #   end
    #
    #   user = GithubUser.find(login: 'heelhook')
    #   user.login           # -> 'heelhook'
    #   user.uppercase_login # -> 'HEELHOOK'
    def proxy_methods(*methods)
      @_methods ||= {}

      methods.each do |method|
        if method.is_a? Symbol
          # If given a symbol, store as a method to overwrite and use the default loader
          proxy_method method
        elsif method.is_a? Hash
          # If its a hash it will include methods to overwrite along with custom loaders
          method.each { |method_name, proc| proxy_method method_name, proc }
        end
      end
    end

    # Method to find a record using a hash as the criteria
    #
    # @example
    #   class GithubUser
    #     include MongoMapper::Document
    #     include ClassProxy
    #
    #     primary_fetch  { |args| where(args).first or (raise NotFound) }
    #     fallback_fetch { |args| Octokit.user(args[:login]) }
    #   end
    #
    #   GithubUser.fetch(login: 'heelhook') # -> Uses primary_fetch
    #                                       # -> and, if NotFound, fallback_fetch
    #
    # @param [ Hash ] args The criteria to use
    # @options options [ true, false] :skip_fallback Don't use fallback methods
    def fetch(args, options={})
      @primary_fetch.is_a?(Proc) ? @primary_fetch[args] : (raise NotFound)
    rescue NotFound
      return nil if options[:skip_fallback]

      run_fallback(args)
    end

    private

    def run_fallback(args, _self=nil)
      _self ||= self.new

      _self.instance_eval "@fallbacks_used ||= []"

      fallback_obj = _self.instance_exec args, &@fallback_fetch

      # Use the after_fallback_method
      _self.instance_exec fallback_obj, &@after_fallback_method if @after_fallback_method.is_a? Proc

      # Go through the keys of the return object and try to use setters
      if fallback_obj and fallback_obj.respond_to? :keys and fallback_obj.keys.respond_to? :each
        fallback_obj.keys.each do |key|
          next unless _self.respond_to? "#{key}="

          # check if its set to something else
          get_method = _self.respond_to?("no_proxy_#{key}") ? "no_proxy_#{key}" : key
          if _self.respond_to? get_method and _self.send(get_method) == nil
            _self.send("#{key}=", fallback_obj.send(key))
          end
        end
      end

      _self.instance_eval '@fallbacks_used << "default"'

      return _self
    end

    def proxy_method(method_name, proc=nil)
      self.class_eval do
        unless self.instance_methods.include? "no_proxy_#{method_name}".to_sym
          alias_method "no_proxy_#{method_name}".to_sym, method_name
        end

        define_method(method_name) do |*args|
          # Use the no_proxy one first
          v = self.send("no_proxy_#{method_name}".to_sym, *args)

          # Since AR calls the getter method when using the setter method
          # to establish the dirty attribute, since the getter is being replaced
          # here and the setter is being used when appropriate, the @mutex_in_call_for
          # prevents endless recursion.
          @mutex_in_call_for ||= []

          return v if v or @mutex_in_call_for.include? method_name

          # Track fallbacks that were used to prevent reusing them (on nil results)
          @fallbacks_used    ||= []

          @mutex_in_call_for << method_name
          fallback_method = "_run_fallback_#{method_name}".to_sym

          custom_fallback = !!self.respond_to?(fallback_method)

          begin
            if custom_fallback and not @fallbacks_used.include? method_name
              send_args = [fallback_method]

              if self.method(fallback_method).arity == 1
                def_fallback_obj = self.class.instance_variable_get(:@fallback_fetch)[self]
                send_args << def_fallback_obj
              end

              @fallbacks_used << method_name
            elsif not custom_fallback and not @fallbacks_used.include? "default"
              args_class = ArgsClass.new(self)
              self.class.send :run_fallback, args_class, self

              # The value might have changed, so check here
              send_args = ["no_proxy_#{method_name}".to_sym]
            end

            v = self.send(*send_args) if send_args
          rescue NotFound
            if custom_fallback and not @fallbacks_used.include? "default"
              # If a custom callback raises NotFound, run the default fallback
              # (if it hasn't been used previously), that way the default fallback
              # has a chance to set the method that had been overriden previously
              custom_fallback = false
              retry
            end
          end
          self.send("#{method_name}=", v) if v and custom_fallback

          @mutex_in_call_for.delete method_name

          return v
        end
      end

      # Now define the fallback that is going to be used
      self.send(:define_method, "_run_fallback_#{method_name}", &proc) if proc.is_a? Proc
    end
  end

  def self.included(receiver)
    receiver.extend ClassMethods
  end

  # This class makes methods accessible as a hash key, useful to pass
  # as a fallback_fetch argument
  class ArgsClass < BasicObject
    def initialize(object)
      @target = object
    end

    def [](key)
      @target.respond_to?(key) ? @target.send(key) : @target[key]
    end

    def inspect
      "ArgsClass [#{@target.inspect}] " +
      (@target.methods - @target.class.methods).join(', ')
    end

    def target
      @target
    end

    def method_missing(method, args={}, &block)
      @target.send(method, *args)
    end
  end
end