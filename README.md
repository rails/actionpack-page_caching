# actionpack-page_caching

Static page caching for Action Pack (removed from core in Rails 4.0).

## Introduction

Page caching is an approach to caching in which response bodies are stored in
files that the web server can serve directly:

1. A request to endpoint _E_ arrives.
2. Its response is calculated and stored in a file _F_.
3. Next time _E_ is requested, the web server sends _F_ directly.

That applies only to GET or HEAD requests whose reponse code is 200, the rest
are ignored.

Unlike caching proxies or other more sophisticated setups, page caching results
in a dramatic speed up while being dead simple at the same time. Awesome
cost/benefit.

The reason for such performance boost is that cached endpoints are
short-circuited by the web server, which is very efficient at serving static
files. Requests to cached endpoints do not even reach your Rails application.

This technique, however, is only suitable for pages that do not need to go
through your Rails stack, precisely. For example, content management systems
like wikis have typically many pages that are a great fit for this approach, but
account-based systems where people log in and manipulate their own data are
often less likely candidates. As a use case you can check, [Rails
Contributors](https://contributors.rubyonrails.org/) makes heavy use of page
caching. Its source code is [here](https://github.com/rails/rails-contributors).

It is not all or nothing, though, in HTML cached pages JavaScript can still
tweak details here and there dynamically as a trade-off.

## Installation

Add this line to your application's `Gemfile`:

``` ruby
gem "actionpack-page_caching"
```

And then execute:

```
$ bundle
```

## Usage

### Enable Caching

Page caching needs caching enabled:

```ruby
config.action_controller.perform_caching = true
```

That goes typically in `config/environments/production.rb`, but you can activate
that flag in any mode.

Since Rails 5 there is a special toggler to easily enable/disable caching in
`development` mode without editing its configuration file. Just execute

```
$ bin/rails dev:cache
```

to enable/disable caching in `development` mode.

### Configure the Cache Directory

#### Default Cache Directory

By default, files are stored below the `public` directory of your Rails
application, with a path that matches the one in the URL.

For example, a page-cached request to `/posts/what-is-new-in-rails-6` would be
stored by default in the file `public/posts/what-is-new-in-rails-6.html`, and
the web server would be configured to check that path in the file system before
falling back to Rails. More on this later.

#### Custom Cache Directory

The default page caching directory can be overridden:

``` ruby
config.action_controller.page_cache_directory = Rails.root.join("public", "cached_pages")
```

There is no need to ensure the directory exists when the application boots,
whenever a page has to be cached, the page cache directory is created if needed.

#### Custom Cache Directory per Controller

The globally configured cache directory, default or custom, can be overridden in
each controller. There are three ways of doing this.

With a lambda:

``` ruby
class WeblogController < ApplicationController
  self.page_cache_directory = -> {
    Rails.root.join("public", request.domain)
  }
end
```

a symbol:

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

Intermediate directories are created as needed also in this case.

### Specify Actions to be Cached

Specifying which actions have to be cached is done through the `caches_page` class method:

``` ruby
class WeblogController < ActionController::Base
  caches_page :show, :new
end
```

### Configure The Web Server

The [wiki](https://github.com/rails/actionpack-page_caching/wiki) of the project
has some examples of web server configuration.

### Cache Expiration

Expiration of the cache is handled by deleting the cached files, which results
in a lazy regeneration approach in which the content is stored again as cached
endpoints are hit.

#### Full Cache Expiration

If the cache is stored in a separate directory like `public/cached_pages`, you
can easily expire the whole thing by removing said directory.

Removing a directory recursively with something like `rm -rf` is unreliable
because that operation is not atomic and can mess up with concurrent page cache
generation.

In POSIX systems moving a file is atomic, so the recommended approach would be
to move the directory first out of the way, and then recursively delete that
one. Something like

```bash
#!/bin/bash

tmp=public/cached_pages-$(date +%s)
mv public/cached_pages $tmp
rm -rf $tmp
```

As noted before, the page cache directory is created if it does not exist, so
moving the directory is enough to have a clean cache, no need to recreate.

#### Fine-grained Cache Expiration

The API for doing so mimics the options from `url_for` and friends:

``` ruby
class WeblogController < ActionController::Base
  def update
    List.update(params[:list][:id], params[:list])
    expire_page action: "show", id: params[:list][:id]
    redirect_to action: "show", id: params[:list][:id]
  end
end
```

Additionally, you can expire caches using
[Sweepers](https://github.com/rails/rails-observers#action-controller-sweeper)
that act on changes in the model to determine when a cache is supposed to be
expired.

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
