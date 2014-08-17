Consul Client
=============

Ruby client library for Consul HTTP API, providing both a thin wrapper around
the raw API and higher level behaviours for operating in a Consul environment.

_This library is experimental! Be sure to thoroughly test and code review
before using for anything real._

Usage
-----

Simple API usage:

```ruby
require 'consul/client'

client = Consul::Client.v1.http
client.get("/agent/self")
```

See `example` directory for more.
