require "digest"
require "fileutils"

# Bytes trailing a JPEG's end-of-image marker are ignored by decoders, so a padded copy of
# a real photo is still processable by libvips. Do not swap the padding for a file of pure
# random bytes: the size-limit tests that pass validation go on to generate variants from it.
module PaddedImageUploads
  PADDED_JPEG_DIRECTORY = "tmp/spec_padded_jpegs".freeze
  SOURCE_JPEG = "spec/fixtures/files/gallery_photo.jpg".freeze

  def padded_jpeg_upload(byte_size)
    Rack::Test::UploadedFile.new(padded_jpeg_path(byte_size), "image/jpeg")
  end

  # Capybara's attach_file takes a path, not an uploaded file, and a 30 MB file is worth
  # handing over rather than copying into a tempfile first.
  def padded_jpeg_path(byte_size)
    source_bytes = Rails.root.join(SOURCE_JPEG).binread
    minimum_byte_size = source_bytes.bytesize

    if byte_size < minimum_byte_size
      raise ArgumentError,
        "Padding only grows a file, so #{byte_size} bytes is unreachable from the " \
        "#{minimum_byte_size}-byte source JPEG. Ask for #{minimum_byte_size} bytes or more."
    end

    # The digest belongs in the filename: keyed on size alone, replacing the source fixture
    # leaves every padded copy in tmp/ stale and still serving the old photo's bytes.
    source_digest = Digest::SHA256.hexdigest(source_bytes).first(12)
    path = Rails.root.join(PADDED_JPEG_DIRECTORY, "#{source_digest}-#{byte_size}.jpg")

    unless path.exist?
      FileUtils.mkdir_p(path.dirname)
      path.binwrite(source_bytes + ("\0" * (byte_size - minimum_byte_size)))
    end

    path
  end
end

RSpec.configure do |config|
  config.include PaddedImageUploads
end
