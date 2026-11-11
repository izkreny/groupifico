# WHY: its own mailer rather than a second method on `MemberMailer`, for the reason that one gives: a different subject, a different link and different copy, about one event rather than the group.
class RegistrationMailer < ApplicationMailer
  helper EventsHelper

  # WHY: the link is the event page with no token in it, so it is no credential, as `MemberMailer.welcome`'s is not: a signed-out member is bounced to the ordinary sign-in form, which works for one who has never signed in.
  def response_requested(registration)
    @event = registration.event
    @group = @event.group

    # WHY: after the event the question is attendance, as `EventsHelper#answer_prompt` asks it on the page.
    question = @event.ended? ? "did you go to" : "are you coming to"

    mail subject: "#{@group.name}: #{question} #{@event.name}?", to: registration.member.email
  end
end
