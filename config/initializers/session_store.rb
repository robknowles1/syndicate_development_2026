# The expiry is written into the encrypted cookie itself, not just into its Max-Age, so a
# cookie captured off the wire or lifted from a shared machine stops being accepted at the
# deadline whether or not the client honours the expiry it was sent. Without it, the only
# things that end a session are a password change and a logout an attacker will not perform.
# A working day, so an admin is not asked to sign in again mid-task.
#
# The key repeats what Rails derives from the application name: naming the store here means
# naming the key too, and changing it would orphan every session cookie already issued.
Rails.application.config.session_store :cookie_store,
  key: "_syndicate_development2026_session",
  expire_after: 12.hours
