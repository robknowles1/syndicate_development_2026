# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

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

# --- Admin User ---
admin_password = ENV.fetch("ADMIN_SEED_PASSWORD") { raise "Set ADMIN_SEED_PASSWORD env var before seeding" }
AdminUser.find_or_create_by(email: "doug@syndicate-development.com") do |u|
  u.password = admin_password
  u.password_confirmation = admin_password
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
