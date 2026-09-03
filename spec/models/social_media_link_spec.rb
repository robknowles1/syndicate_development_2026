require "rails_helper"

RSpec.describe SocialMediaLink, type: :model do
  describe "validations" do
    context "with an allowlisted platform and an https url" do
      it "is valid (AT1, R1, R2, R4, AC-1)" do
        # Arrange
        link = build(:social_media_link, platform: "instagram", url: "https://instagram.com/syndicate")

        # Act / Assert
        expect(link).to be_valid
      end
    end

    context "with a platform outside the allowlist" do
      it "is invalid with an inclusion error (AT2, R2, AC-2)" do
        # Arrange
        link = build(:social_media_link, platform: "myspace")

        # Act
        link.valid?

        # Assert
        expect(link.errors.details[:platform]).to include(a_hash_including(error: :inclusion))
      end
    end

    context "with a platform already used by an inactive row" do
      it "is invalid with a uniqueness error (AT3, R3, AC-3, E7)" do
        # Arrange
        create(:social_media_link, platform: "instagram", active: false, position: 0)
        duplicate = build(:social_media_link, platform: "instagram", position: 1)

        # Act
        duplicate.valid?

        # Assert
        expect(duplicate.errors.details[:platform]).to include(a_hash_including(error: :taken))
      end
    end

    context "without a url" do
      it "is invalid with a presence error (AT4, R4, AC-4)" do
        # Arrange
        link = build(:social_media_link, url: "")

        # Act
        link.valid?

        # Assert
        expect(link.errors.details[:url]).to include(a_hash_including(error: :blank))
      end
    end

    context "with a javascript scheme url" do
      it "is invalid with a format error (AT5, R4, R11, AC-5, E6)" do
        # Arrange
        link = build(:social_media_link, url: "javascript:alert(1)")

        # Act
        link.valid?

        # Assert
        expect(link.errors.details[:url]).to include(a_hash_including(error: :invalid))
      end
    end

    context "with a javascript url that embeds an https substring" do
      it "is still invalid, because the format is anchored (R4, E6)" do
        # Arrange
        link = build(:social_media_link, url: 'javascript:alert("https://instagram.com")')

        # Act / Assert
        expect(link).not_to be_valid
      end
    end

    context "with an ftp scheme url" do
      it "is invalid (AT6, R4, AC-6)" do
        # Arrange
        link = build(:social_media_link, url: "ftp://example.com/shop")

        # Act / Assert
        expect(link).not_to be_valid
      end
    end

    context "with a schemeless url" do
      it "is invalid, and the scheme is never inferred (R4, E11)" do
        # Arrange
        link = build(:social_media_link, url: "instagram.com/shop")

        # Act / Assert
        expect(link).not_to be_valid
      end
    end

    context "with a mailto url" do
      it "is invalid (R4)" do
        # Arrange
        link = build(:social_media_link, url: "mailto:doug@example.com")

        # Act / Assert
        expect(link).not_to be_valid
      end
    end

    context "with an uppercase scheme" do
      it "is valid, because scheme matching is case-insensitive (R4, E10)" do
        # Arrange
        link = build(:social_media_link, url: "HTTPS://instagram.com/shop")

        # Act / Assert
        expect(link).to be_valid
      end
    end

    [ "https://", "https:///", "https://:80", "https://@", "https://?x=1", "https://#frag" ].each do |empty_host_url|
      context "with the host-less url #{empty_host_url.inspect}" do
        it "is invalid, because a scheme alone is not a well-formed URL (R4)" do
          # Arrange
          link = build(:social_media_link, url: empty_host_url)

          # Act
          link.valid?

          # Assert
          expect(link.errors.details[:url]).to include(a_hash_including(error: :invalid))
        end
      end
    end

    context "with a host-less url" do
      it "reports the invalid format exactly once (R4)" do
        # Arrange
        link = build(:social_media_link, url: "https://")

        # Act
        link.valid?

        # Assert
        expect(link.errors[:url].size).to eq(1)
      end
    end

    context "with a url whose userinfo hides a second host" do
      it "is invalid, because it cannot be parsed into a single host (R4)" do
        # Arrange
        link = build(:social_media_link, url: "https://user:pass@evil.com@instagram.com")

        # Act
        link.valid?

        # Assert
        expect(link.errors.details[:url]).to include(a_hash_including(error: :invalid))
      end
    end

    context "with a non-integer position" do
      it "is invalid (R5)" do
        # Arrange
        link = build(:social_media_link, position: nil)

        # Act / Assert
        expect(link).not_to be_valid
      end
    end
  end

  describe "PLATFORMS" do
    it "is a frozen allowlist of exactly the 7 supported platforms (R2)" do
      # Act / Assert
      expect(described_class::PLATFORMS)
        .to contain_exactly("instagram", "facebook", "youtube", "tiktok", "x", "threads", "linkedin")
      expect(described_class::PLATFORMS).to be_frozen
    end
  end

  describe "#icon_key" do
    SocialMediaLink::PLATFORMS.each do |platform|
      context "with the #{platform} platform" do
        it "returns brand-#{platform} (AT7, R7, AC-7)" do
          # Arrange
          link = build(:social_media_link, platform: platform)

          # Act / Assert
          expect(link.icon_key).to eq("brand-#{platform}")
        end
      end
    end
  end

  describe "#platform_label" do
    it "resolves through the shared social_media i18n namespace (R7, AC-30)" do
      # Arrange
      link = build(:social_media_link, platform: "x")

      # Act / Assert
      expect(link.platform_label).to eq(I18n.t("social_media.platforms.x"))
    end

    SocialMediaLink::PLATFORMS.each do |platform|
      context "with the #{platform} platform" do
        it "returns a defined translation (R7, AC-30)" do
          # Arrange
          link = build(:social_media_link, platform: platform)

          # Act / Assert
          expect(link.platform_label).not_to match(/translation missing/i)
        end
      end
    end
  end

  describe ".active" do
    context "with a mix of active and inactive rows" do
      it "returns only the active rows, in position order (AT8, R6, R18, AC-8)" do
        # Arrange
        create(:social_media_link, platform: "facebook", position: 1)
        create(:social_media_link, platform: "instagram", position: 0)
        create(:social_media_link, platform: "youtube", position: 2, active: false)

        # Act
        platforms = described_class.active.order(:position).map(&:platform)

        # Assert
        expect(platforms).to eq(%w[instagram facebook])
      end
    end
  end

  describe "the active default" do
    context "without an explicit active value" do
      it "defaults to true (AT9, R1, AC-9)" do
        # Arrange
        link = described_class.new

        # Act / Assert
        expect(link.active).to be(true)
      end
    end
  end
end
