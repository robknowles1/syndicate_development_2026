module Admin
  module ImagePreviewsHelper
    # Do not reduce this to `attached?`. A file rejected by validation is still attached in
    # memory while the form re-renders at 422, but its blob was never saved, and asking an
    # unsaved blob for a variant URL raises instead of rendering the error state (E5).
    def image_preview_available?(attachment)
      attachment.attached? && attachment.blob.persisted?
    end
  end
end
