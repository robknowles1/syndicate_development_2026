require "fileutils"

# Bytes trailing a JPEG's end-of-image marker are ignored by decoders, so a padded copy of
# a real photo is still processable by libvips. Do not swap the padding for a file of pure
# random bytes: the size-limit tests that pass validation go on to generate variants from it.
module PaddedImageUploads
  PADDED_JPEG_DIRECTORY = "tmp/spec_padded_jpegs".freeze

  def padded_jpeg_upload(byte_size)
    path = Rails.root.join(PADDED_JPEG_DIRECTORY, "#{byte_size}.jpg")

    unless path.exist?
      FileUtils.mkdir_p(path.dirname)
      source_bytes = Rails.root.join("spec/fixtures/files/gallery_photo.jpg").binread
      path.binwrite(source_bytes + ("\0" * (byte_size - source_bytes.bytesize)))
    end

    Rack::Test::UploadedFile.new(path, "image/jpeg")
  end
end

RSpec.configure do |config|
  config.include PaddedImageUploads
end
