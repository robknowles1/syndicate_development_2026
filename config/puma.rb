# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# You can control the number of workers using ENV["WEB_CONCURRENCY"]. You
# should only set this value when you want to run 2 or more workers. The
# default is already 1. You can set it to `auto` to automatically start a worker
# for each available processor.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments.
#
# Compared against the string "true" rather than tested for bare presence. Kamal
# writes `KEY=` into the container environment for a variable it knows about but
# has no value for, and a destination can override an inherited key but never
# remove one — so under a presence test the values "", "false" and "no" would all
# start a supervisor, because every string is truthy in Ruby. An explicit
# comparison makes the flag switchable off and makes any unexpected value fail
# in the safe direction: no supervisor, jobs left queued, rather than a
# supervisor dying against a database with no solid_queue_* tables and taking
# the Puma master down with it.
#
# Which hosts set this is decided in config/deploy.yml via the `solid_queue` env
# tag, and spec/config/solid_queue_supervisor_spec.rb holds the two in agreement.
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"] == "true"

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
