This demonstrates using an external coordinator process to safely perform
a rolling restart of a cluster to update it to a new version.

On a control node, set the active version:

    curl -X PUT  localhost:8500/v1/kv/version -d 'abc123'

On each vagrant node, after starting consul, start a restarter:

    cd /vagrant/example/orchestrated && ruby2.1 -I../../lib restarter.rb

On one arbitrary node, start a coordinator:

    cd /vagrant/example/orchestrated && ruby2.1 -I../../lib coordinator.rb

Now change the active version:

    curl -X PUT  localhost:8500/v1/kv/version -d 'abc456'

Observe that all restarters are updated to the latest version, while
maintaining at least `MIN_NODES` (default: 1) healthy at all times. This
process is resilient to crashes in any process.
