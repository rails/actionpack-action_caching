actionpack-action_caching
=========================

Action caching for Action Pack (removed from core in Rails 4.0).

Installation
------------

Add this line to your application's Gemfile:

```ruby
gem 'actionpack-action_caching'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install actionpack-action_caching

Usage
-----

Action caching is similar to page caching by the fact that the entire
output of the response is cached, but unlike page caching, every
request still goes through Action Pack. The key benefit of this is
that filters run before the cache is served, which allows for
authentication and other restrictions on whether someone is allowed
to execute such action.

```ruby
class ListsController < ApplicationController
  before_action :authenticate, except: :public

  caches_page   :public
  caches_action :index, :show
end
```

In this example, the `public` action doesn't require authentication
so it's possible to use the faster page caching. On the other hand
`index` and `show` require authentication. They can still be cached,
but we need action caching for them.

Action caching uses fragment caching internally and an around
filter to do the job. The fragment cache is named according to
the host and path of the request. A page that is accessed at
`http://david.example.com/lists/show/1` will result in a fragment named
`david.example.com/lists/show/1`. This allows the cacher to
differentiate between `david.example.com/lists/` and
`jamis.example.com/lists/` -- which is a helpful way of assisting
the subdomain-as-account-key pattern.

Different representations of the same resource, e.g.
`http://david.example.com/lists` and
`http://david.example.com/lists.xml`
are treated like separate requests and so are cached separately.
Keep in mind when expiring an action cache that
`action: "lists"` is not the same as
`action: "list", format: :xml`.

You can modify the default action cache path by passing a
`:cache_path` option. This will be passed directly to
`ActionCachePath.new`. This is handy for actions with
multiple possible routes that should be cached differently. If a
proc (or an object that responds to `to_proc`) is given, it is
called with the current controller instance.

And you can also use `:if` (or `:unless`) to control when the action
should be cached, similar to how you use them with `before_action`.

As of Rails 3.0, you can also pass `:expires_in` with a time
interval (in seconds) to schedule expiration of the cached item.

The following example depicts some of the points made above:

```ruby
class ListsController < ApplicationController
  before_action :authenticate, except: :public

  # simple fragment cache
  caches_action :current

  # expire cache after an hour
  caches_action :archived, expires_in: 1.hour

  # cache unless it's a JSON request
  caches_action :index, unless: -> { request.format.json? }

  # custom cache path
  caches_action :show, cache_path: { project: 1 }

  # custom cache path with a proc
  caches_action :history, cache_path: -> { request.domain }

  # custom cache path with a symbol
  caches_action :feed, cache_path: :user_cache_path

  protected
    def user_cache_path
      if params[:user_id]
        user_list_url(params[:user_id], params[:id])
      else
        list_url(params[:id])
      end
    end
end
```

If you pass `layout: false`, it will only cache your action
content. That's useful when your layout has dynamic information.

Note: Both the `:format` param and the `Accept` header are taken
into account when caching the fragment with the `:format` having
precedence. For backwards compatibility when the `Accept` header
indicates a HTML request the fragment is stored without the
extension but if an explicit `"html"` is passed in `:format` then
that _is_ used for storing the fragment.

Contributing
------------

1. Fork it.
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Commit your changes (`git commit -am 'Add some feature'`).
4. Push to the branch (`git push origin my-new-feature`).
5. Create a new Pull Request.

Code Status
-----------

* [![Build Status](https://github.com/rails/actionpack-action_caching/actions/workflows/ci.yml/badge.svg)](https://github.com/rails/actionpack-action_caching/actions/workflows/ci.yml)
