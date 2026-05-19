# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

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
    slug: "precision_engines",
    heading: "PRECISION ENGINES",
    bullets: [
      "Full engine builds and rebuilds",
      "Top-end and bottom-end service",
      "Porting and head work",
      "Valve train service and upgrades",
      "Engine blueprinting and balancing"
    ]
  },
  {
    slug: "custom_suspension_setup",
    heading: "CUSTOM SUSPENSION SETUP",
    bullets: [
      "Revalving and re-springing for rider weight and style",
      "Fork and shock servicing",
      "Linkage and bearing service",
      "Track-day and race setup",
      "Dyno-verified suspension tuning"
    ]
  },
  {
    slug: "ecu_tuning",
    heading: "ECU TUNING",
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
  existing = ServiceSection.find_by(slug: data[:slug])
  next if existing

  section = ServiceSection.create!(slug: data[:slug], heading: data[:heading])
  data[:bullets].each_with_index do |body, index|
    section.service_bullets.create!(body: body, position: index)
  end
end
