## 1.1.2 (June 12, 2015)

*   Added Control-Cache headers support

    *Alex Yusupov*

*   Call `to_s` on the extension as it may be a symbol

    Fixes #10

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
