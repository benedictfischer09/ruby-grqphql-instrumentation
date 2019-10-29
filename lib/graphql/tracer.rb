# frozen_string_literal: true

require 'graphql/opentracing/version'
require 'active_support'

module GraphQL
  module Tracer
    class IncompatibleGemVersion < StandardError; end

    class << self
      attr_accessor :ignore_request, :tracer

      IgnoreRequest = ->(_name, _metadata) { false }

      def instrument(schema: nil, tracer: OpenTracing.global_tracer,
                     ignore_request: IgnoreRequest)
        begin
          require 'graphql'
        rescue LoadError
          return
        end
        raise IncompatibleGemVersion unless compatible_version?

        @schema = schema
        @ignore_request = ignore_request
        @tracer = tracer
        install_tracer
      end

      def compatible_version?
        # support for ActiveSupportNotificationsTracing
        Gem::Version.new(GraphQL::VERSION) >= Gem::Version.new('1.7.0')
      end

      def install_tracer
        @schema.tracer self if @schema
      end

      def trace(key, metadata)
        return yield if @ignore_request.call(key, metadata)

        @tracer.start_active_span("graphql.#{key}", tags: {
                                    'component' => 'ruby-graphql',
                                    'span.kind' => 'server'
                                  }) do |scope|
          begin
            yield
          rescue StandardError
            scope.span.set_tag('error', true)
            raise
          end
        end
      end
    end
  end
end
