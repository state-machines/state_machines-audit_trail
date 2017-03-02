[![Build Status](https://travis-ci.org/state-machines/state_machines-audit_trail.svg?branch=master)](https://travis-ci.org/state-machines/state_machines-audit_trail)
[![Code Climate](https://codeclimate.com/github/state-machines/state_machines-audit_trail.png)](https://codeclimate.com/github/state-machines/state_machines-audit_trail)

# state_machines-audit_trail
Log transitions on a [state_machines gem](https://github.com/state-machines/state_machines) to support auditing and business process analytics.


## Description

This plugin for the [state_machines gem](https://github.com/state-machines/state_machines) adds support for keeping an audit trail
for any state machine. Having an audit trail gives you a complete history of the state changes in your model. This history allows you
to investigate incidents or perform analytics, like: _"How long does it take on average to go from state a to state b?"_,
or _"What percentage of cases goes from state a to b via state c?"_

For more information read [Why developers should be force-fed state machines](http://www.shopify.com/technology/3383012-why-developers-should-be-force-fed-state-machines).

## ORM support

Note: while the state_machines gem integrates with multiple ORMs, this plugin is currently limited to the following ORM backends:

*   ActiveRecord
*   Mongoid


It should be easy to add new backends by looking at the implementation of the current backends. Pull requests are welcome!

## Installation
First, make the gem available by adding it to your `Gemfile`, and run `bundle install`:

```ruby

# this gem
gem 'state_machines-audit_trail'

# required runtime dependency for your ORM; either
gem 'state_machines-activerecord'

# OR
gem 'state_machines-mongoid'
```

## Usage

For the examples below, we will assume you have a pre-existing model called `Subscription` that has a `state_machine` configured to utilize the `state` attribute.

### Create/generate a model and migration that holds the audit trail specific to your target model
A Rails generator is provided to create a model and a migration, call it with:

```ruby
rails generate state_machines:audit_trail Subscription state
```

will generate the `SubscriptionStateTransition` model and an accompanying migration.

### Configure `audit_trail` in your `state_machine`:

```ruby
class Subscription < ActiveRecord::Base
  state_machine :state, initial: :start do
    audit_trail
    ...
```

### That's it!
`audit_trail` will register an `after_transition` callback that is used to log all transitions including the initial state if there is one.

## Upgrading from state_machine-audit_trail

See the wiki, https://github.com/state-machines/state_machines-audit_trail/wiki/Converting-from-former-state_machine-audit_trail-to-state_machines-audit_trail

## Configuration options

### `:initial` - turn off initial state logging
By default, upon instantiation, a `StateTransition` is saved for `null => initial` state.  This is useful to understand the full history
of any model, but there are cases where this can pollute the `audit_trail`.  For example, when a model has multiple `state_machine`s
that use a single `StateTransition` model for persistence (in conjunction with `context` below), there would be multiple initial state
transitions.  By configuring `initial: false`, it will skip the initial state transition logging for this specific `state_machine`, while
leaving the others in the model unaffected.
```ruby
audit_trail initial: false
```

### `:class` - custom state transition class
If your `Transition` model does not use the default naming scheme, provide it using the `:class` option:
```ruby
audit_trail class: FooStateTransition
```

An example use of a custom `:class` and `:context` (below) would be for a model that has multiple `state_machine` definitions.  The combination
of these options would allow the use of one transition class that logged state information from both state machines.

### `:context` - storing additional attribute or method values
Using the `:context` option, you can store method results (or attributes exposed as methods) in the state transition class.

In order to utilize this feature, you need to:

1. add a field/column to your state transition class (i.e. `SubscriptionStateTransitions`) and perhaps underlying database through a migration
2. expose the attribute as a method, or create a method to compute a dynamic value
3. configure `:context`

#### Example 1 - Store a single attribute value
Store `Subscription` `field1` in `Transition` field `field1`:
```ruby
audit_trail context: :field1
```

#### Example 2 - Store multiple attribute values
Store `Subscription` `field1` and `field2` in `Transition` fields `field1` and `field2`:
```ruby
audit_trail context: [:field1, :field2]
```

#### Example 3 - Store multiple values from a single context object
Store `Subscription` `user` in `Transition` fields `user_id` and `user_name`:
```ruby
class Subscription < ActiveRecord::Base
  state_machines :state, initial: :start do
    audit_trail context: :user
    ...
  end
end

class SubscriptionStateTransition < ActiveRecord::Base
  def user=(u)
    self.user_id = u.id
    self.user_name = u.name
  end
end
```

#### Example 4 - Store simple method results
Store simple method results.

Sometimes it can be useful to store dynamically computed information, such as those from a `Subscription`  method `#plan_time_remaining`


```ruby
class Subscription < ActiveRecord::Base
  state_machines :state, initial: :start do
    audit_trail :context: :plan_time_remaining
    ...

  def plan_time_remaining
    # Dynamically computed field e.g., based on other models
    ...
```

#### Example 5 - Store advanced method results
Store method results that interrogate the transition for information such as `event` arguments:

```ruby
class Subscription < ActiveRecord::Base
  state_machines :state, initial: :start do
    audit_trail :context: :user_name
    ...

  # method receives a state_machines transition object
  def user_name(transition)
    if transition.args.present?
      user_id = transition.args.last.delete(:user_id)
      User.find(user_id).name
    else
      'Undefined User'
    end
    ...

model = Subscription.first
model.ignite!('arg1, 'arg2', 'arg3', user_id: 1)
```

## About

### Maintainers
Conversion from the original code to `state_machines` by [AlienFast](http://alienfast.com).

### Original Authors
[The original plugin](https://github.com/wvanbergen/state_machine-audit_trail) was written by Jesse Storimer and Willem van Bergen for Shopify.
Mongoid support was contributed by [Siddharth](https://github.com/svs).

### License
Released under the MIT license (see LICENSE).

## Contributing

1. Fork it ( https://github.com/state-machines/state_machines-audit_trail/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
