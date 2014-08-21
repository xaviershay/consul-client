This example shows gradually moving traffic from one deploy to another using
client-side loadbalancing and smart server updating.

After setting a _spec_ for the ratio of traffic that should go to each version
of code, the cluster will dynamically reconfigure itself to be able to serve
that load, while clients will start routing traffic according to the split.

On a control node, set the spec in the KV store:

    curl -X PUT --data '{"abc123": 0.1, "def456": 0.9}' \
      localhost:8500/v1/kv/testdrive/spec

On each consul node, start a server and an updater:

    foreman start

If you are running with vagrant and shared mounts, `VFILE` and `DFILE` need to
be unique file for each process:

    running from a vagrant shared mount.
    VFILE=VERSION DFILE=down foreman start

In a three node cluster, two nodes will be running `def456` and one will be
running `abc123`.

Start the client in a loop:

    while true; do ruby client.rb; done

You will see that it is load balancing only 10% of requests to `abc123`. Move
to 40/60 and see what happens:

    curl -X PUT --data '{"abc123": 0.4, "def456": 0.6}' \
      localhost:8500/v1/kv/testdrive/spec

With more traffic now going to `def456`, one node in the cluster will migrate
to that version.

Finally, move all traffic to `def456`:

    curl -X PUT --data '{"def456": 1.0}' \
      localhost:8500/v1/kv/testdrive/spec

Immediately all client traffic is routed to `def456`, while the final node
migrates itself off `abc123`.
