require "rails_helper"

RSpec.describe "db/seeds.rb FAQ seeding", type: :request do
  def seed
    original = ENV["ADMIN_SEED_PASSWORD"]
    ENV["ADMIN_SEED_PASSWORD"] = "seed-password-1234"
    Rails.application.load_seed
  ensure
    original.nil? ? ENV.delete("ADMIN_SEED_PASSWORD") : ENV["ADMIN_SEED_PASSWORD"] = original
  end

  def sign_in_admin
    admin = create(:admin_user)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
    admin
  end

  def expected_seed_faqs
    [
      [ "What suspension work does Syndicate Development offer?",
        "We handle full suspension service for motocross and supercross bikes — revalving and re-springing tuned to your weight and riding style, fork and shock rebuilds, linkage and bearing service, and setup for track day or race day. Whether you're running stock components or a full custom suspension package, we tune it to how you actually ride." ],
      [ "Do you build complete race engines?",
        "Yes. We do full engine builds and rebuilds for motocross and supercross bikes, including top-end and bottom-end service, porting and head work, valve train upgrades, and engine blueprinting and balancing. Every build is set up and verified on our in-house dyno before it goes back to you." ],
      [ "Can you tune my bike's ECU?",
        "We do fuel injection mapping, ignition timing, and custom ECU tuning for fuel-injected motocross and supercross bikes, including launch and traction control setup and custom maps for aftermarket exhausts and air kits. All tuning is dyno-verified, not guesswork." ],
      [ "How long does a typical job take?",
        "Turnaround depends on the scope of the work — a suspension service or ECU tune is usually quicker than a full engine build. Give us a call or send a message with what you need done and we'll give you a realistic timeline before you drop the bike off." ],
      [ "Do you work on stock or trail bikes, or only race bikes?",
        "Both. While we specialize in custom performance work for motocross and supercross machines, we also handle regular servicing for stock and trail bikes — from routine maintenance to the same suspension and engine work we do for race bikes." ],
      [ "Do customers travel from outside Pocatello for work here?",
        "Yes — we take suspension, engine, and ECU work from riders across southeast Idaho and the surrounding region, not just Pocatello. If you're coming from out of town, give us a call ahead of time so we can plan your build or service around your trip and have parts ready when you arrive." ]
    ]
  end

  context "with a clean database" do
    it "creates the six spec'd FAQs verbatim at positions 0 to 5 (AT52, AC-61)" do
      # Act
      seed

      # Assert
      expect(Faq.order(:position).pluck(:question, :answer)).to eq(expected_seed_faqs)
      expect(Faq.order(:position).pluck(:position)).to eq([ 0, 1, 2, 3, 4, 5 ])
    end
  end

  context "when seeding runs twice with no admin edits in between" do
    it "leaves the six rows alone rather than duplicating them (AT53, AC-62, E26)" do
      # Arrange
      seed

      # Act
      seed

      # Assert
      expect(Faq.count).to eq(6)
      expect(Faq.pluck(:question).uniq.length).to eq(6)
    end
  end

  context "when an admin has edited a seeded answer" do
    it "keeps the edited answer through a reseed (AT54, AC-63, E27)" do
      # Arrange
      seed
      sign_in_admin
      edited = Faq.order(:position).first
      patch admin_faq_path(edited), params: { faq: { question: edited.question, answer: "Doug's own words." } }

      # Act
      seed

      # Assert
      expect(edited.reload.answer).to eq("Doug's own words.")
      expect(Faq.count).to eq(6)
    end
  end

  context "when an admin has reworded a seeded question" do
    it "keeps the reworded question and creates no duplicate row (AT55, AC-64, E28)" do
      # Arrange
      seed
      sign_in_admin
      original_question = "Can you tune my bike's ECU?"
      edited = Faq.find_by!(question: original_question)
      patch admin_faq_path(edited), params: { faq: { question: "Do you do ECU tuning?", answer: edited.answer } }

      # Act
      seed

      # Assert
      expect(edited.reload.question).to eq("Do you do ECU tuning?")
      expect(Faq.count).to eq(6)
      expect(Faq.find_by(question: original_question)).to be_nil
    end
  end

  context "when an admin has deleted three of the six seeded rows" do
    it "resurrects none of them on a reseed (AT56, AC-65, E29)" do
      # Arrange
      seed
      sign_in_admin
      deleted_questions = Faq.order(:position).last(3).map(&:question)
      Faq.order(:position).last(3).each { |faq| delete admin_faq_path(faq) }

      # Act
      seed

      # Assert
      expect(Faq.count).to eq(3)
      expect(Faq.where(question: deleted_questions)).to be_empty
    end
  end

  context "when an admin has deleted every seeded row" do
    it "recreates all six verbatim, an empty table being indistinguishable from a fresh install (AT57, AC-66, E30)" do
      # Arrange
      seed
      sign_in_admin
      Faq.find_each { |faq| delete admin_faq_path(faq) }

      # Act
      seed

      # Assert
      expect(Faq.order(:position).pluck(:question, :answer)).to eq(expected_seed_faqs)
      expect(Faq.order(:position).pluck(:position)).to eq([ 0, 1, 2, 3, 4, 5 ])
    end
  end
end
