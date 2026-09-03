require "rails_helper"

RSpec.describe "Admin::SocialMediaLinks", type: :request do
  def sign_in_admin
    admin = create(:admin_user)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
    admin
  end

  def nav_links(response_body)
    aria_label = I18n.t("admin.layout.nav.aria_label")
    Nokogiri::HTML(response_body).at_css("nav[aria-label='#{aria_label}']").css("a")
  end

  describe "GET /admin/social_media_links" do
    context "without any links" do
      it "shows the empty state and an add-first call to action (AT10, R8, AC-10)" do
        # Arrange
        sign_in_admin

        # Act
        get admin_social_media_links_path

        # Assert
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("admin.social_media_links.empty_state"))
        expect(response.body).to include(I18n.t("admin.social_media_links.add_first"))
      end
    end

    context "with links out of insertion order" do
      it "lists them in position order (R8, R18)" do
        # Arrange
        sign_in_admin
        create(:social_media_link, platform: "facebook", position: 1)
        create(:social_media_link, platform: "instagram", position: 0)

        # Act
        get admin_social_media_links_path

        # Assert
        expect(response.body.index(I18n.t("social_media.platforms.instagram")))
          .to be < response.body.index(I18n.t("social_media.platforms.facebook"))
      end
    end

    context "with an inactive link" do
      it "still lists it, so it can be edited or re-activated (R6, E2)" do
        # Arrange
        sign_in_admin
        create(:social_media_link, platform: "youtube", active: false, position: 0)

        # Act
        get admin_social_media_links_path

        # Assert
        expect(response.body).to include(I18n.t("social_media.platforms.youtube"))
        expect(response.body).to include(I18n.t("admin.social_media_links.inactive_badge"))
      end
    end
  end

  describe "GET /admin/social_media_links/new" do
    context "when authenticated" do
      it "renders exactly 7 platform options labelled with human-readable names (AT16, AC-16, AC-30)" do
        # Arrange
        sign_in_admin
        expected_labels = SocialMediaLink::PLATFORMS.map { |p| I18n.t("social_media.platforms.#{p}") }

        # Act
        get new_admin_social_media_link_path
        options = Nokogiri::HTML(response.body).css("select#social_media_link_platform option")

        # Assert
        expect(options.size).to eq(7)
        expect(options.map(&:text).map(&:strip)).to eq(expected_labels)
        expect(options.map { |o| o["value"] }).to eq(SocialMediaLink::PLATFORMS)
      end
    end

    context "when authenticated and building a new record" do
      it "renders the active checkbox already checked (AT17, R8, AC-17)" do
        # Arrange
        sign_in_admin

        # Act
        get new_admin_social_media_link_path
        checkbox = Nokogiri::HTML(response.body).at_css("input[type=checkbox][name='social_media_link[active]']")

        # Assert
        expect(checkbox).to be_present
        expect(checkbox["checked"]).to be_present
      end
    end

    context "when authenticated on a phone-sized form" do
      it "gives the inputs full width and the save button a large tap target (CLAUDE.md mobile-first)" do
        # Arrange
        sign_in_admin

        # Act
        get new_admin_social_media_link_path
        form = Nokogiri::HTML(response.body)

        # Assert
        expect(form.at_css("#social_media_link_platform")[:class]).to include("w-full")
        expect(form.at_css("#social_media_link_url")[:class]).to include("w-full")
        expect(form.at_css("input[type=submit]")[:class]).to include("py-3")
      end
    end
  end

  describe "POST /admin/social_media_links" do
    context "without any existing links" do
      it "creates the first link at position 0 (AT11, R5, R8, AC-11)" do
        # Arrange
        sign_in_admin

        # Act
        post admin_social_media_links_path,
             params: { social_media_link: { platform: "instagram", url: "https://instagram.com/shop", active: "true" } }

        # Assert
        expect(response).to redirect_to(admin_social_media_links_path)
        expect(flash[:notice]).to eq(I18n.t("admin.social_media_links.flash.created"))
        expect(SocialMediaLink.sole).to have_attributes(platform: "instagram", position: 0, active: true)
      end
    end

    context "with a link already at position 0" do
      it "creates the next link at position 1 (AT11, R5, AC-11)" do
        # Arrange
        sign_in_admin
        create(:social_media_link, platform: "instagram", position: 0)

        # Act
        post admin_social_media_links_path,
             params: { social_media_link: { platform: "facebook", url: "https://facebook.com/shop" } }

        # Assert
        expect(SocialMediaLink.find_by(platform: "facebook").position).to eq(1)
      end
    end

    context "with a platform that is already in use" do
      it "returns 422 and re-renders new with a uniqueness error (AT12, R3, AC-12, E7)" do
        # Arrange
        sign_in_admin
        create(:social_media_link, platform: "instagram", position: 0)

        # Act
        post admin_social_media_links_path,
             params: { social_media_link: { platform: "instagram", url: "https://instagram.com/other" } }

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(SocialMediaLink.count).to eq(1)
        expect(response.body).to include(I18n.t("errors.messages.taken"))
      end
    end

    context "with a javascript url" do
      it "returns 422 and persists nothing (R4, AC-5, E6)" do
        # Arrange
        sign_in_admin

        # Act
        post admin_social_media_links_path,
             params: { social_media_link: { platform: "instagram", url: "javascript:alert(1)" } }

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(SocialMediaLink.count).to eq(0)
      end
    end

    context "with the active checkbox unticked" do
      it "creates a hidden link (R6)" do
        # Arrange
        sign_in_admin

        # Act
        post admin_social_media_links_path,
             params: { social_media_link: { platform: "threads", url: "https://threads.net/shop", active: "false" } }

        # Assert
        expect(SocialMediaLink.sole.active).to be(false)
      end
    end
  end

  describe "GET /admin/social_media_links/:id/edit" do
    context "with an existing link" do
      it "pre-populates the platform and url (R8)" do
        # Arrange
        sign_in_admin
        link = create(:social_media_link, platform: "tiktok", url: "https://tiktok.com/@shop")

        # Act
        get edit_admin_social_media_link_path(link)
        document = Nokogiri::HTML(response.body)

        # Assert
        expect(response).to have_http_status(:ok)
        expect(document.at_css("option[value=tiktok]")["selected"]).to be_present
        expect(document.at_css("#social_media_link_url")["value"]).to eq("https://tiktok.com/@shop")
      end
    end

    context "with an inactive link" do
      it "renders the active checkbox unchecked (R6, R8)" do
        # Arrange
        sign_in_admin
        link = create(:social_media_link, platform: "x", active: false)

        # Act
        get edit_admin_social_media_link_path(link)
        checkbox = Nokogiri::HTML(response.body).at_css("input[type=checkbox][name='social_media_link[active]']")

        # Assert
        expect(checkbox["checked"]).to be_nil
      end
    end
  end

  describe "PATCH /admin/social_media_links/:id" do
    context "with a valid new url" do
      it "updates the row and redirects with a notice (AT13, R8, AC-13)" do
        # Arrange
        sign_in_admin
        link = create(:social_media_link, platform: "instagram", url: "https://instagram.com/before")

        # Act
        patch admin_social_media_link_path(link),
              params: { social_media_link: { platform: "instagram", url: "https://instagram.com/after" } }

        # Assert
        expect(response).to redirect_to(admin_social_media_links_path)
        expect(flash[:notice]).to eq(I18n.t("admin.social_media_links.flash.updated"))
        expect(link.reload.url).to eq("https://instagram.com/after")
      end
    end

    context "with a javascript url" do
      it "returns 422 and leaves the row unchanged (R4, E6)" do
        # Arrange
        sign_in_admin
        link = create(:social_media_link, platform: "instagram", url: "https://instagram.com/before")

        # Act
        patch admin_social_media_link_path(link),
              params: { social_media_link: { platform: "instagram", url: "javascript:alert(1)" } }

        # Assert
        expect(response).to have_http_status(:unprocessable_entity)
        expect(link.reload.url).to eq("https://instagram.com/before")
      end
    end
  end

  describe "DELETE /admin/social_media_links/:id" do
    context "with an existing link" do
      it "removes the row and redirects with a notice (AT14, R8, AC-14)" do
        # Arrange
        sign_in_admin
        link = create(:social_media_link)

        # Act
        delete admin_social_media_link_path(link)

        # Assert
        expect(response).to redirect_to(admin_social_media_links_path)
        expect(flash[:notice]).to eq(I18n.t("admin.social_media_links.flash.destroyed"))
        expect(SocialMediaLink.find_by(id: link.id)).to be_nil
      end
    end
  end

  describe "PATCH /admin/social_media_links/:id/move_up" do
    context "with a lower-positioned neighbour" do
      it "swaps the two positions (AT15, R8, AC-15)" do
        # Arrange
        sign_in_admin
        first = create(:social_media_link, platform: "instagram", position: 0)
        second = create(:social_media_link, platform: "facebook", position: 1)

        # Act
        patch move_up_admin_social_media_link_path(second)

        # Assert
        expect(response).to redirect_to(admin_social_media_links_path)
        expect(first.reload.position).to eq(1)
        expect(second.reload.position).to eq(0)
      end
    end

    context "with a gap between neighbouring positions" do
      it "swaps with the nearest lower neighbour rather than decrementing (R5)" do
        # Arrange
        sign_in_admin
        first = create(:social_media_link, platform: "instagram", position: 0)
        second = create(:social_media_link, platform: "facebook", position: 5)

        # Act
        patch move_up_admin_social_media_link_path(second)

        # Assert
        expect(first.reload.position).to eq(5)
        expect(second.reload.position).to eq(0)
      end
    end

    context "without a lower-positioned neighbour" do
      it "is a no-op that does not raise (AT15, AC-15, E8)" do
        # Arrange
        sign_in_admin
        lowest = create(:social_media_link, platform: "instagram", position: 0)

        # Act
        patch move_up_admin_social_media_link_path(lowest)

        # Assert
        expect(response).to redirect_to(admin_social_media_links_path)
        expect(lowest.reload.position).to eq(0)
      end
    end
  end

  describe "PATCH /admin/social_media_links/:id/move_down" do
    context "with a higher-positioned neighbour" do
      it "swaps the two positions (AT15, R8, AC-15)" do
        # Arrange
        sign_in_admin
        first = create(:social_media_link, platform: "instagram", position: 0)
        second = create(:social_media_link, platform: "facebook", position: 1)

        # Act
        patch move_down_admin_social_media_link_path(first)

        # Assert
        expect(first.reload.position).to eq(1)
        expect(second.reload.position).to eq(0)
      end
    end

    context "without a higher-positioned neighbour" do
      it "is a no-op that does not raise (AT15, AC-15, E8)" do
        # Arrange
        sign_in_admin
        highest = create(:social_media_link, platform: "instagram", position: 0)

        # Act
        patch move_down_admin_social_media_link_path(highest)

        # Assert
        expect(highest.reload.position).to eq(0)
      end
    end
  end

  describe "the admin nav entry" do
    context "when authenticated on the index, new and edit pages" do
      it "marks Social current on each of them (AT19, R9, AC-19)" do
        # Arrange
        sign_in_admin
        link = create(:social_media_link, platform: "instagram")
        social_label = I18n.t("admin.layout.nav.social")

        # Act / Assert
        [ admin_social_media_links_path,
          new_admin_social_media_link_path,
          edit_admin_social_media_link_path(link) ].each do |path|
          get path

          current = nav_links(response.body).select { |a| a["aria-current"] == "page" }
          expect(current.map { |a| a.text.strip }).to eq([ social_label ]),
            "expected Social marked current on #{path}"
        end
      end
    end

    context "when authenticated" do
      it "appends Social after Services rather than inserting it mid-list (R9, AC-19)" do
        # Arrange
        sign_in_admin

        # Act
        get admin_social_media_links_path
        labels = nav_links(response.body).map { |a| a.text.strip }

        # Assert
        expect(labels.last).to eq(I18n.t("admin.layout.nav.social"))
        expect(labels[-2]).to eq(I18n.t("admin.layout.nav.services"))
      end
    end
  end

  describe "GET /admin" do
    context "when authenticated" do
      it "links to the social media links screen from the dashboard (AT20, R10, AC-20)" do
        # Arrange
        sign_in_admin

        # Act
        get admin_root_path
        main_links = Nokogiri::HTML(response.body).css("ul a").map { |a| a["href"] }

        # Assert
        expect(main_links).to include(admin_social_media_links_path)
        expect(response.body).to include(I18n.t("admin.dashboard.social_media_links_link"))
      end
    end
  end

  describe "when there is no active admin session (AT18, R8, AC-18)" do
    it "redirects every route to login and changes no data" do
      # Arrange
      link = create(:social_media_link, platform: "instagram", url: "https://instagram.com/original", position: 0)
      create(:social_media_link, platform: "facebook", position: 1)

      # Act / Assert
      [ -> { get admin_social_media_links_path },
        -> { get new_admin_social_media_link_path },
        -> { post admin_social_media_links_path, params: { social_media_link: { platform: "x", url: "https://x.com/s" } } },
        -> { get edit_admin_social_media_link_path(link) },
        -> { patch admin_social_media_link_path(link), params: { social_media_link: { url: "https://instagram.com/hacked" } } },
        -> { delete admin_social_media_link_path(link) },
        -> { patch move_up_admin_social_media_link_path(link) },
        -> { patch move_down_admin_social_media_link_path(link) } ].each do |request|
        request.call
        expect(response).to redirect_to(admin_login_path)
      end

      expect(SocialMediaLink.count).to eq(2)
      expect(link.reload).to have_attributes(url: "https://instagram.com/original", position: 0)
    end
  end
end
