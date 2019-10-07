# frozen_string_literal: true

require 'graphql'
require 'opentracing'

class QueryType < GraphQL::Schema::Object
  graphql_name 'Query'

  field :hello, String, null: true
  def hello
    'hello world!'
  end
end
class SampleSchema < GraphQL::Schema
  query(QueryType)
end

RSpec.describe GraphQL::Tracer do
  describe '.instrument' do
    it 'adds active support instrumentation' do
      expect do
        described_class.instrument
      end.to change(GraphQL::Tracing.tracers, :count).by(1)
    end

    it 'detects existing active support instrumentation' do
      GraphQL::Tracing.install(GraphQL::Tracing::ActiveSupportNotificationsTracing)

      expect do
        described_class.instrument
      end.not_to change(GraphQL::Tracing.tracers, :count)
    end

    context 'with instrumented schema' do
      let(:query_string) do
        <<-GRAPHQL
        query greeting {
          hello
        }
        GRAPHQL
      end

      it 'start and finshes a span for a GQL event' do
        span = double(finish: true)
        tracer = double(start_span: span)
        described_class.instrument(tracer: tracer)
        execute_query(query_string)
        expect(tracer).to have_received(:start_span).at_least(:once)
        expect(span).to have_received(:finish).at_least(:once)
      end

      it 'can be configured to skip creating a span for some events' do
        span = double(finish: true)
        tracer = double(start_span: span)
        described_class.instrument(
          tracer: tracer,
          ignore_request: ->(name, _started, _finished, _id, _data) { name.include?('graphql') }
        )

        execute_query(query_string)
        expect(tracer).not_to have_received(:start_span)
        expect(span).not_to have_received(:finish)
      end

      it 'follows semantic conventions for the span tags' do
        span = double(finish: true)
        tracer = double(start_span: span)
        described_class.instrument(tracer: tracer)
        execute_query(query_string)

        expect(tracer).to have_received(:start_span).with(
          'graphql',
          start_time: anything,
          tags: {
            'component' => 'ruby-graphql',
            'span.kind' => 'server',
            'operation' => 'graphql.execute_query'
          }
        ).at_least(:once)
      end

      xit 'tags the span as an error when the response is an error' do
        span = double(finish: true, set_tag: true)
        tracer = double(start_span: span)
        described_class.instrument(tracer: tracer)
        execute_query(query_string, context: { errors: ['a'] })

        expect(span).to have_received(:set_tag).at_least(:once)
      end
    end

    def execute_query(string, variables = {}, context: {})
      GraphQL::Query.new(SampleSchema, string, variables: variables, context: context).result
    end
  end
end
