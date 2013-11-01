## 1.1.0

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
