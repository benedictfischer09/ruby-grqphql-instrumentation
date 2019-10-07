require 'graphql/opentracing/version'
require 'active_support'

module GraphQL
  module Tracer
    class IncompatibleGemVersion < StandardError; end;

    class << self
      attr_accessor :ignore_request, :tracer

      IgnoreRequest = ->(_name, _started, _finished, _id, _data) { false }
      CheckErrors = -> (_name, _started, _finished, _id, data) { data[:context]&.errors&.any? }
      def instrument(tracer: OpenTracing.global_tracer, ignore_request: IgnoreRequest, check_errors: CheckErrors)
        begin
          require 'graphql'
        rescue LoadError
          return
        end
        raise IncompatibleGemVersion unless compatible_version?

        @ignore_request = ignore_request
        @check_errors = check_errors
        @tracer = tracer
        install_active_support_notifications
        subscribe_active_support_notifications
      end

      def compatible_version?
        # support for ActiveSupportNotificationsTracing
        Gem::Version.new(GraphQL::VERSION) >= Gem::Version.new('1.7.0')
      end

      def install_active_support_notifications
        GraphQL::Tracing.install(GraphQL::Tracing::ActiveSupportNotificationsTracing)
      end

      def subscribe_active_support_notifications
        ActiveSupport::Notifications.subscribe(/^graphql/) do |name, started, finished, id, data|
          next if @ignore_request.call(name, started, finished, id, data)

          tags = {
            "component" => "ruby-graphql",
            "span.kind" => "server",
            "operation" => name
          }
          span = tracer.start_span("graphql",
            tags: tags,
            start_time: started)

          span.set_tag("error", true) if @check_errors.call(name, started, finished, id, data)
          span.finish(end_time: finished)
        end
      end
    end
  end
end
