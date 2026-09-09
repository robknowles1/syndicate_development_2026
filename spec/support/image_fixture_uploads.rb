require "stringio"

module ImageFixtureUploads
  module_function

  # Active Storage uploads this io after the record commits, not when attach returns, so
  # wrapping a call site in File.open's block form closes the handle before the upload and
  # saving raises IOError. Holding the bytes is what makes the descriptor safe to release.
  def image_fixture_io(filename)
    StringIO.new(Rails.root.join("spec/fixtures/files", filename).binread)
  end
end

RSpec.configure do |config|
  config.include ImageFixtureUploads
end
