class PagesController < ApplicationController
  def home
  end

  def about
  end

  def gallery
    @images = Dir.glob(Rails.root.join("app/assets/images/gallery/*.jpg")).map do |path|
      "gallery/#{File.basename(path)}"
    end.sort
  end
end
