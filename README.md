Consul Client
=============

Ruby client library for Consul HTTP API, providing both a thin wrapper around
the raw API and higher level behaviours for operating in a Consul environment.

_This library is experimental and unmaintained! You probably shouldn't use it! Have you tried [Diplomat](https://github.com/WeAreFarmGeek/diplomat)?_

Usage
-----

It's a gem:

    gem install consul-client

Simple API usage:

```ruby
require 'consul/client'

client = Consul::Client.v1.http
client.get("/agent/self")
```

See `example` directory for more:

* `puts_service.rb` is a minimum server that demostrates coordinated shutdown.
* `http_service.rb` builds on top of webrick for an auto-updating server with
  coordinated restart.

A `Vagrantfile` is provided that makes three
Consul nodes, which is handy for playing around.

Documentation
-------------

[Comprehensive YARD documentation is
available](http://rubydoc.info/github/xaviershay/consul-client/master), though
honestly you're probably better off just working from the `example` directory.
