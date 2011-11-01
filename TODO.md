# Planned Changes

Also take a look at the [issues page](/rubycas/rubycas-client/issues)

## Version 2.4

1. Support for Ruby 1.9.3
1. Integration with travis for CI
  1. Test against Rails 2.3
  1. Test without Rails
  1. Test against 1.8.7, 1.9.2, 1.9.3, jruby

## Version 3.0

1. Convert test cases from riot to rspec2 - Done!
1. Move Service Callback, PGT Callback and Single Sign Out Callback to
   a Rack Middleware.

## Version 3.1

1. Cleanup the way Ticket Store integration works
1. Improve test coverage for CASClient::Client
1. Remove dependency on activesupport (expect in Rails specific classes)
1. Support for Rails 3.0 and 3.1

## Future

1. Support for other Rubies (JRuby, Rubinius, etc.)
1. Support for Rails 3.2

# Documentation Needs

## Improve/Rewrite Documentation

The documentation isn't the clearest and is now a bit out of date. That
needs addressing

## Examples

We could use some new and/or improved examples for

1. Rails 2.3
1. Rails 3.x
1. Sinatra
