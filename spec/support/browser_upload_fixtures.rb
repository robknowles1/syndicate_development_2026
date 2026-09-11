require "fileutils"

# Chrome derives File.type from the filename's extension, not the bytes, so the extension is
# the whole point of these fixtures: ".mp4" is what makes the browser report "video/mp4", and
# an extensionless name is what makes it report "". Writing real container headers would
# change nothing, and renaming one of these files silently disarms the guard it exercises.
module BrowserUploadFixtures
  BROWSER_UPLOAD_DIRECTORY = "tmp/spec_browser_upload_fixtures".freeze

  def browser_upload_path(filename, byte_size: 1.kilobyte)
    path = Rails.root.join(BROWSER_UPLOAD_DIRECTORY, filename)

    unless path.exist? && path.size == byte_size
      FileUtils.mkdir_p(path.dirname)
      path.binwrite("\0" * byte_size)
    end

    path.to_s
  end
end

RSpec.configure do |config|
  config.include BrowserUploadFixtures
end
