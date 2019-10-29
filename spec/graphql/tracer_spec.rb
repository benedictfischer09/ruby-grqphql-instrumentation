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
    context 'with instrumented schema' do
      let(:query_string) do
        <<-GRAPHQL
        query greeting {
          hello
        }
        GRAPHQL
      end

      it 'starts a span for a GQL event' do
        tracer = double(start_active_span: nil)
        described_class.instrument(tracer: tracer, schema: SampleSchema)
        execute_query(query_string)
        expect(tracer).to have_received(:start_active_span).at_least(:once)
      end

      it 'can be configured to skip creating a span for some events' do
        tracer = double(start_active_span: nil)
        described_class.instrument(
          schema: SampleSchema,
          tracer: tracer,
          ignore_request: ->(_name, _data) { true }
        )

        execute_query(query_string)
        expect(tracer).not_to have_received(:start_active_span)
      end

      it 'follows semantic conventions for the span tags' do
        tracer = double(start_active_span: nil)
        described_class.instrument(schema: SampleSchema, tracer: tracer)
        execute_query(query_string)

        expect(tracer).to have_received(:start_active_span).with(
          'graphql.execute_multiplex',
          tags: {
            'component' => 'ruby-graphql',
            'span.kind' => 'server'
          }
        ).at_least(:once)
      end

      it 'tags the span as an error an exception is raised' do
        allow_any_instance_of(QueryType).to receive(:hello).and_raise('error')

        tracer = double
        span = double(set_tag: nil)
        scope = double(span: span)
        allow(tracer).to receive(:start_active_span).and_yield(scope)
        described_class.instrument(
          schema: SampleSchema,
          tracer: tracer
        )
        begin
          execute_query(query_string)
        rescue
        end

        expect(span).to have_received(:set_tag).with('error', true)
                                               .at_least(:once)
      end
    end

    def execute_query(string, variables = {}, context: {})
      GraphQL::Query.new(SampleSchema,
                         string,
                         variables: variables,
                         context: context).result
    end
  end
end
