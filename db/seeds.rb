# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Validated before anything is written: db:prepare seeds only the databases it created in
# that same run, so a deploy that seeds badly is not repaired by redeploying, and a partial
# seed would have to be finished by hand. The bounds are read from the model rather than
# restated so the seed cannot drift from the validations that will judge the record.
minimum_password_length = AdminUser::MINIMUM_PASSWORD_LENGTH
maximum_password_bytes = ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED
admin_seed_password = ENV["ADMIN_SEED_PASSWORD"]

# Deliberately not ENV.fetch: its default block fires only when the key is absent, and Kamal
# writes `ADMIN_SEED_PASSWORD=` into the container when the secret resolves to nothing.
if admin_seed_password.nil?
  raise "ADMIN_SEED_PASSWORD is not set. Seeding needs it to create the admin accounts."
elsif admin_seed_password.blank?
  raise "ADMIN_SEED_PASSWORD is set but blank. Check that the secret resolves to a value."
elsif admin_seed_password.length < minimum_password_length
  raise "ADMIN_SEED_PASSWORD is too short: #{admin_seed_password.length} characters, minimum #{minimum_password_length}."
elsif admin_seed_password.bytesize > maximum_password_bytes
  raise "ADMIN_SEED_PASSWORD is too long: #{admin_seed_password.bytesize} bytes, maximum #{maximum_password_bytes}."
end

# --- Home Page Content ---
home_content = HomePageContent.first_or_initialize
if home_content.new_record?
  home_content.assign_attributes(
    hero_tagline: "Performance, Passion, Precision.",
    mission_heading: "DREAM IT. BUILD IT. RIDE IT. LOVE IT.",
    mission_subheading: "SPECIALIZING IN CUSTOM PERFORMANCE MOTOCROSS AND SUPERCROSS MOTORCYCLES",
    mission_body: I18n.t("pages.home.mission_body"),
    published: false
  )
  home_content.save!
end

# --- About Page Content ---
about_content = AboutPageContent.first_or_initialize
if about_content.new_record?
  about_content.assign_attributes(
    shop_heading: "SYNDICATE DEVELOPMENT",
    shop_phone_label: "Shop Phone:",
    shop_phone_number: "208-251-9536",
    shop_address_label: "Shop Address:",
    shop_address: "1801 N. Arthur Ave., Pocatello, ID, 83204",
    bio_heading: "About Doug Haskett",
    bio_body: I18n.t("pages.about.bio_body"),
    slideshow_alt_1: "Syndicate Development motorcycle 1",
    slideshow_alt_2: "Syndicate Development motorcycle 2",
    slideshow_alt_3: "Syndicate Development motorcycle 3",
    published: false
  )
  about_content.save!
end

# --- Admin Users ---
# The block runs only on create, so re-seeding never resets the password of an admin who
# has since changed it.
[ "robknowles105@gmail.com", "haskettd@live.com" ].each do |admin_email|
  AdminUser.find_or_create_by!(email: admin_email) do |admin_user|
    admin_user.password = admin_seed_password
    admin_user.password_confirmation = admin_seed_password
  end
end

# --- Site Settings ---
SiteSetting.find_or_create_by(key: "services_page_published") { |s| s.value = "false" }

# --- Service Sections with Bullets ---
sections_data = [
  {
    heading: "PRECISION ENGINES",
    icon_key: "settings",
    position: 0,
    bullets: [
      "Full engine builds and rebuilds",
      "Top-end and bottom-end service",
      "Porting and head work",
      "Valve train service and upgrades",
      "Engine blueprinting and balancing"
    ]
  },
  {
    heading: "CUSTOM SUSPENSION SETUP",
    icon_key: "adjustments-horizontal",
    position: 1,
    bullets: [
      "Revalving and re-springing for rider weight and style",
      "Fork and shock servicing",
      "Linkage and bearing service",
      "Track-day and race setup",
      "Dyno-verified suspension tuning"
    ]
  },
  {
    heading: "ECU TUNING",
    icon_key: "cpu",
    position: 2,
    bullets: [
      "Fuel injection mapping and fuel curve optimization",
      "Ignition timing adjustment",
      "Launch control and traction control configuration",
      "Dyno-tuned power delivery",
      "Custom maps for aftermarket exhausts and air kits"
    ]
  }
]

sections_data.each do |data|
  derived_slug = data[:heading].parameterize(separator: "_")
  section = ServiceSection.find_by(heading: data[:heading]) ||
            ServiceSection.find_by(slug: derived_slug) ||
            ServiceSection.find_by(slug: "custom_suspension")

  if section
    section.update_columns(icon_key: data[:icon_key], position: data[:position])
  else
    section = ServiceSection.new(
      heading: data[:heading],
      icon_key: data[:icon_key],
      position: data[:position]
    )
    # Build at least one bullet so the at_least_one_bullet validation passes on create
    data[:bullets].each_with_index do |body, index|
      section.service_bullets.build(body: body, position: index)
    end
    section.save!
    next
  end

  data[:bullets].each_with_index do |body, index|
    ServiceBullet.find_or_create_by!(service_section: section, position: index) { |b| b.body = body }
  end
end

faq_seed_content = [
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

# Guarded on the table, never on a row: every column here is admin-editable, so a per-row
# lookup would recreate a FAQ the admin had reworded or deliberately deleted.
if Faq.count.zero?
  faq_seed_content.each_with_index do |(question, answer), position|
    Faq.create!(question: question, answer: answer, position: position)
  end
end
