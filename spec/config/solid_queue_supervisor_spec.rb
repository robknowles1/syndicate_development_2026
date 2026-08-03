require "rails_helper"
require "kamal"

# Holds the deploy configuration and the app configuration in agreement about
# where a Solid Queue supervisor runs.
#
# The failure this exists to prevent has no runtime signature on either side.
# Set SOLID_QUEUE_IN_PUMA where there is no queue database and the supervisor
# dies on boot — and Puma's solid_queue plugin answers that by signalling the
# Puma master, so the web tier goes down with it. Leave it unset where the job
# adapter IS :solid_queue and every `deliver_later` is accepted, written to the
# queue database, and never run: no error, no failed deploy, no email.
#
# Both halves are configuration, so nothing else in the suite covers them.
#
# Discovery is by glob, not by a hardcoded list, so a destination added later is
# checked the day it is added rather than the day it breaks something.
RSpec.describe "Solid Queue supervisor placement", type: :config do
  # nil is the base config with no destination — production, for this repo.
  destinations = [ nil, *Dir["config/deploy.*.yml"].map { |f| f[/deploy\.(.+)\.yml/, 1] } ]

  # Baked into the Dockerfile, so a host that does not override RAILS_ENV runs
  # this one.
  default_rails_env = "production"

  # An environment needs a supervisor exactly when Active Record gives it a
  # `queue` database to write jobs to. Read from config/database.yml rather than
  # restated here, so this cannot drift from the thing it describes.
  def environments_with_a_queue_database
    raw = ERB.new(File.read("config/database.yml")).result
    YAML.load(raw, aliases: true).filter_map do |env_name, settings|
      env_name if settings.is_a?(Hash) && settings["queue"].is_a?(Hash)
    end
  end

  # Kamal's own resolution path — the one that builds `docker run --env` args.
  # Only `clear` is read; secrets are never resolved, so this needs no
  # credentials and shells out to nothing.
  def clear_env_per_host(destination)
    config = Kamal::Configuration.create_from(
      config_file: Pathname.new("config/deploy.yml"),
      destination: destination
    )

    config.roles.flat_map do |role|
      role.hosts.map { |host| [ "#{role.name}@#{host}", role.env(host).clear ] }
    end
  end

  around do |example|
    # Kamal::Configuration.create_from writes this as a side effect.
    original = ENV["KAMAL_DESTINATION"]
    example.run
  ensure
    ENV["KAMAL_DESTINATION"] = original
  end

  it "reads the queue database from config/database.yml" do
    # Guards the helper above: if the production block is ever restructured so
    # that no environment matches, every expectation below would pass vacuously.
    expect(environments_with_a_queue_database).to include("production")
  end

  destinations.each do |destination|
    context "destination #{destination || '(base)'}" do
      it "sets SOLID_QUEUE_IN_PUMA on exactly the hosts whose Rails environment has a queue database" do
        needs_supervisor = environments_with_a_queue_database

        clear_env_per_host(destination).each do |host_label, clear|
          rails_env = clear.fetch("RAILS_ENV", default_rails_env)
          expected = needs_supervisor.include?(rails_env)
          actual = clear["SOLID_QUEUE_IN_PUMA"] == "true"

          expect(actual).to eq(expected),
            lambda {
              if expected
                "#{host_label} runs RAILS_ENV=#{rails_env}, which has a `queue` database and an " \
                "Active Job adapter of :solid_queue, but SOLID_QUEUE_IN_PUMA is " \
                "#{clear['SOLID_QUEUE_IN_PUMA'].inspect}. Jobs enqueued there would never run. " \
                "Tag the host `solid_queue` in config/deploy.yml, or give it a dedicated job role."
              else
                "#{host_label} runs RAILS_ENV=#{rails_env}, which has no `queue` database, but " \
                "SOLID_QUEUE_IN_PUMA is #{clear['SOLID_QUEUE_IN_PUMA'].inspect}. The supervisor " \
                "would die on boot and Puma's solid_queue plugin would take the web tier with it. " \
                "Remove the `solid_queue` tag from this host in config/deploy.yml — note that " \
                "setting the flag to \"false\" in env.clear does NOT work, because a destination " \
                "can override an inherited key but not remove it."
              end
            }
        end
      end
    end
  end

  it "gates the Puma plugin on the exact string, so a non-\"true\" value cannot enable it" do
    # The scoping above is only as good as this comparison. Under a bare
    # presence test (`if ENV["SOLID_QUEUE_IN_PUMA"]`) an empty or "false" value
    # would still start the supervisor.
    expect(File.read("config/puma.rb")).to include('ENV["SOLID_QUEUE_IN_PUMA"] == "true"')
  end
end
