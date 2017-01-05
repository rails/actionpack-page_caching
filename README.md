actionpack-page_caching
=======================

Static page caching for Action Pack (removed from core in Rails 4.0).

Installation
------------

Add this line to your application's Gemfile:

``` ruby
gem "actionpack-page_caching"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install actionpack-page_caching

Usage
-----

Page caching is an approach to caching where the entire action output is
stored as a HTML file that the web server can serve without going through
Action Pack. This is the fastest way to cache your content as opposed to going
dynamically through the process of generating the content. Unfortunately, this
incredible speed-up is only available to stateless pages where all visitors are
treated the same. Content management systems -- including weblogs and wikis --
have many pages that are a great fit for this approach, but account-based systems
where people log in and manipulate their own data are often less likely candidates.

First you need to set `page_cache_directory` in your configuration file:

``` ruby
config.action_controller.page_cache_directory = "#{Rails.root}/public/cached_pages"
```

The `page_cache_directory` setting can be used with a Proc:

``` ruby
class WeblogController < ApplicationController
  self.page_cache_directory = -> { Rails.root.join("public", request.domain) }
end
```

a Symbol:

``` ruby
class WeblogController < ApplicationController
  self.page_cache_directory = :domain_cache_directory

  private
    def domain_cache_directory
      Rails.root.join("public", request.domain)
    end
end
```

or a callable object:

``` ruby
class DomainCacheDirectory
  def self.call(request)
    Rails.root.join("public", request.domain)
  end
end

class WeblogController < ApplicationController
  self.page_cache_directory = DomainCacheDirectory
end
```

Specifying which actions to cache is done through the `caches_page` class method:

``` ruby
class WeblogController < ActionController::Base
  caches_page :show, :new
end
```

This will generate cache files such as `weblog/show/5.html` and
`weblog/new.html`, which match the URLs used that would normally trigger
dynamic page generation. Page caching works by configuring a web server to first
check for the existence of files on disk, and to serve them directly when found,
without passing the request through to Action Pack. This is much faster than
handling the full dynamic request in the usual way.

Expiration of the cache is handled by deleting the cached file, which results
in a lazy regeneration approach where the cache is not restored before another
hit is made against it. The API for doing so mimics the options from `url_for`
and friends:

``` ruby
class WeblogController < ActionController::Base
  def update
    List.update(params[:list][:id], params[:list])
    expire_page action: "show", id: params[:list][:id]
    redirect_to action: "show", id: params[:list][:id]
  end
end
```

Additionally, you can expire caches using [Sweepers](https://github.com/rails/rails-observers#action-controller-sweeper)
that act on changes in the model to determine when a cache is supposed to be expired.

Finally, configure your web server to serve these static pages when they are present
rather than the original files. See the [project wiki][1] for example configurations.
[1]: https://github.com/rails/actionpack-page_caching/wiki

Contributing
------------

1. Fork it.
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Commit your changes (`git commit -am 'Add some feature'`).
4. Push to the branch (`git push origin my-new-feature`).
5. Create a new Pull Request.

Code Status
-----------

* [![Build Status](https://travis-ci.org/rails/actionpack-page_caching.svg?branch=master)](https://travis-ci.org/rails/actionpack-page_caching)
* [![Dependency Status](https://gemnasium.com/rails/actionpack-page_caching.svg)](https://gemnasium.com/rails/actionpack-page_caching)
