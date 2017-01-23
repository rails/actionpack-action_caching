## 1.2.0 (January 23, 2014)

*   Support proc options with zero arguments

    Fixes #40.

    *Andrew White*

*   The options `:layout` and `:cache_path` now behave the same when
    passed a `Symbol`, `Proc` or object that responds to call.

    *Andrew White*

*   Respect `Accept` header when caching actions

    Fixes #18.

    *Andrew White*

*   Support Rails 4.0, 4.1, 4.2, 5.0 and edge

    *Eileen Uchitelle*, *Andrew White*

*   Call `to_s` on the extension as it may be a symbol

    Fixes #10.

    *Andrew White*


## 1.1.1 (January 2, 2014)

*   Fix load order problem with other gems

    *Andrew White*


## 1.1.0 (November 1, 2013)

*   Allow to use non-proc object in `cache_path` option. You can pass an object that
    responds to a `call` method.

    Example:

        class CachePath
          def call(controller)
            controller.id
          end
        end

        class TestController < ApplicationController
          caches_action :index, :cache_path => CachePath.new
          def index; end
        end

    *Piotr Niełacny*


## 1.0.0 (February 28, 2013)

*   Extract Action Pack - Action Caching from Rails core.

    *Francesco Rodriguez*
