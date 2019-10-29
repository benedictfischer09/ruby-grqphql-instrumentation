# GraphQL Opentracing

Open Tracing instrumentation for the [graphql gem](https://github.com/rmosolgo/graphql-ruby). By default it starts a new span for every request handled by graphql. It follows the open tracing tagging [semantic conventions](https://opentracing.io/specification/conventions)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'graphql-opentracing'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install graphql-opentracing

## Usage
First load the opentracing (Note: this won't automatically instrument the graphql gem)
```
require "graphql-opentracing"
```

If you have setup `OpenTracing.global_tracer` you can turn on spans for all requests with just:
```
    GraphQL::Tracer.instrument
```

You must also modify your GQL schema to add the ActiveSupportNotifications tracer provided by the GQL gem

```
tracer(GraphQL::Tracing::ActiveSupportNotificationsTracing)
```

Under the hood this gem subscribes to graphql instrumentation events through the ActiveSupport notifications framework. If you find the number of spans too noisy you can control which spans are reported though a callback like:
```
GraphQl::Tracer.instrument(
    schema: MyGQLSchema,
    tracer: tracer,
    ignore_request: ->(name, started, finished, id, data) { !name.include? 'execute_query' }
)
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/benedictfischer09/ruby-graphql-instrumentation. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/benedictfischer09/ruby-graphql-instrumentation/blob/master/CODE_OF_CONDUCT.md).
