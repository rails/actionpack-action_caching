actionpack-action_caching
=========================

Action caching for Action Pack (removed from core in Rails 4.0).

**NOTE:** It will continue to be officially maintained until Rails 4.1.

Installation
------------

Add this line to your application's Gemfile:

    gem 'actionpack-action_caching'

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

    class ListsController < ApplicationController
      before_filter :authenticate, except: :public

      caches_page   :public
      caches_action :index, :show
    end

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
`action: 'lists'` is not the same as
`action: 'list', format: :xml`.

You can modify the default action cache path by passing a
`:cache_path` option. This will be passed directly to
`ActionCachePath.new`. This is handy for actions with
multiple possible routes that should be cached differently. If a
block is given, it is called with the current controller instance.

And you can also use `:if` (or `:unless`) to pass a
proc that specifies when the action should be cached.

As of Rails 3.0, you can also pass `:expires_in` with a time
interval (in seconds) to schedule expiration of the cached item.

The following example depicts some of the points made above:

    class ListsController < ApplicationController
      before_filter :authenticate, except: :public

      caches_page :public

      caches_action :index, if: Proc.new do
        !request.format.json?  # cache if is not a JSON request
      end

      caches_action :show, cache_path: { project: 1 },
        expires_in: 1.hour

      caches_action :feed, cache_path: Proc.new do
        if params[:user_id]
          user_list_url(params[:user_id], params[:id])
        else
          list_url(params[:id])
        end
      end
    end

If you pass `layout: false`, it will only cache your action
content. That's useful when your layout has dynamic information.

Warning: If the format of the request is determined by the Accept HTTP
header the Content-Type of the cached response could be wrong because
no information about the MIME type is stored in the cache key. So, if
you first ask for MIME type M in the Accept header, a cache entry is
created, and then perform a second request to the same resource asking
for a different MIME type, you'd get the content cached for M.

The `:format` parameter is taken into account though. The safest
way to cache by MIME type is to pass the format in the route.

Contributing
------------

1. Fork it.
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Commit your changes (`git commit -am 'Add some feature'`).
4. Push to the branch (`git push origin my-new-feature`).
5. Create a new Pull Request.

Code Status
-----------

* [![Build Status](https://travis-ci.org/rails/actionpack-action_caching.png?branch=master)](https://travis-ci.org/rails/actionpack-action_caching)
* [![Dependency Status](https://gemnasium.com/rails/actionpack-action_caching.png)](https://gemnasium.com/rails/actionpack-action_caching)
