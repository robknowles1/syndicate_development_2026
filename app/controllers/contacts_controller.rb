class ContactsController < ApplicationController
  MINIMUM_SECONDS_BEFORE_SUBMIT = 2

  # These two must stay above the rate limits. rate_limit registers its before_action
  # where it is written, and rate_limiting spends a bucket slot on every request that
  # reaches it — so moved below, a bot spraying rejected submissions would exhaust a
  # real visitor's allowance.
  before_action :reject_if_honeypot_filled, only: :create
  before_action :reject_if_submitted_too_quickly, only: :create

  rate_limit to: 5, within: 10.minutes, only: :create, name: "contact_per_ip",
    by: -> { request.remote_ip },
    with: -> { reject_as_spam("rate_limit", limit: "contact_per_ip") }

  rate_limit to: 3, within: 10.minutes, only: :create, name: "contact_per_email",
    by: -> { params[:email].to_s.strip.downcase },
    with: -> { reject_as_spam("rate_limit", limit: "contact_per_email") },
    # Skips the limit rather than keying blank emails to one shared bucket: rate_limiting
    # builds its cache key with .compact, so a nil or blank `by` collapses them into one.
    if: -> { params[:email].to_s.strip.present? }

  def create
    name = params[:name].to_s.strip
    email = params[:email].to_s.strip
    phone = params[:phone].to_s.strip
    subject = params[:subject].to_s.strip
    message = params[:message].to_s.strip

    if name.blank? || email.blank? || message.blank?
      redirect_to about_path, alert: I18n.t("contact.errors.missing_required_fields")
    else
      ContactMailer.contact_email(
        name: name,
        email: email,
        phone: phone,
        subject: subject.presence || I18n.t("contact.form.no_subject"),
        message: message
      ).deliver_now
      redirect_to about_path, notice: I18n.t("contact.notices.message_sent")
    end
  end

  private

  def reject_if_honeypot_filled
    reject_as_spam("honeypot") if params[:website].present?
  end

  def reject_if_submitted_too_quickly
    reject_as_spam("timing") unless submitted_after_minimum_delay?
  end

  def submitted_after_minimum_delay?
    rendered_at = Rails.application.message_verifier(:contact_form).verify(params[:rendered_at])
    Time.current.to_i - rendered_at >= MINIMUM_SECONDS_BEFORE_SUBMIT
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    false
  end

  # No submitted field value belongs in this line: the log is neither access-controlled
  # nor retention-bounded, and the request's own entry already records filtered params.
  def reject_as_spam(reason, limit: nil)
    details = [ "contact form rejected", "reason=#{reason}", ("limit=#{limit}" if limit), "ip=#{request.remote_ip}" ]
    Rails.logger.warn(details.compact.join(" "))
    fake_success_response
  end

  def fake_success_response
    redirect_to about_path, notice: I18n.t("contact.notices.message_sent")
  end
end
