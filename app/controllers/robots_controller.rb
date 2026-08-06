class RobotsController < ApplicationController
  def show
    @crawlable = Rails.env.production?
  end
end
