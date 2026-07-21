require "rails_helper"

RSpec.describe "Admin::GalleryPhotos routing", type: :routing do
  describe "removed move_up/move_down member routes" do
    it "no longer routes PATCH /admin/gallery_photos/:id/move_up (AT32, R27, AC-33)" do
      expect(patch: "/admin/gallery_photos/1/move_up").not_to be_routable
    end

    it "no longer routes PATCH /admin/gallery_photos/:id/move_down (AT32, R27, AC-33)" do
      expect(patch: "/admin/gallery_photos/1/move_down").not_to be_routable
    end
  end

  describe "reorder collection route" do
    it "routes PATCH /admin/gallery_photos/reorder to #reorder" do
      expect(patch: "/admin/gallery_photos/reorder").to route_to("admin/gallery_photos#reorder")
    end
  end
end
