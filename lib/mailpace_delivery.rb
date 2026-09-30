require "net/http"

# WHY: passwordless email is the only way into this application, so every answer other than a 200
# raises. A swallowed delivery is indistinguishable from a broken sign-in and leaves nothing
# behind to find it by.
class MailpaceDelivery
  class Error < StandardError; end

  ENDPOINT = URI("https://app.mailpace.com/api/v1/send")

  attr_accessor :settings

  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    response = post(payload_for(mail))

    if response.is_a?(Net::HTTPOK)
      response
    else
      raise Error, [ "MailPace answered #{response.code}", reason_in(response.body) ].compact.join(": ")
    end
  end

  private
    def post(payload)
      Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true) do |http|
        http.post(ENDPOINT.path, payload.to_json, headers)
      end
    end

    # WHY: only what this application's mailers set. MailPace also takes cc, bcc, replyto,
    # attachments and more, and a mailer that starts setting one of those has to add it here,
    # because nothing else carries it across.
    def payload_for(mail)
      # WHY: `mail.from` returns the bare address, and the header field keeps the display name.
      { from: mail[:from].to_s, to: mail.to.join(","), subject: mail.subject, **bodies_of(mail) }.compact
    end

    def bodies_of(mail)
      if mail.multipart?
        { htmlbody: mail.html_part&.decoded, textbody: mail.text_part&.decoded }
      elsif mail.mime_type == "text/html"
        { htmlbody: mail.decoded }
      else
        { textbody: mail.decoded }
      end
    end

    def headers
      {
        "Accept"                => "application/json",
        "Content-Type"          => "application/json",
        "MailPace-Server-Token" => settings[:api_token]
      }
    end

    # WHY: MailPace's own errors are JSON, but an edge in front of it answers HTML and its 500
    # answers nothing, and the status code alone still has to raise.
    def reason_in(body)
      case JSON.parse(body.to_s, symbolize_names: true)
      in { error: String => reason }
        reason
      in { errors: Hash => errors }
        errors.map { |field, messages| "#{field} #{Array(messages).to_sentence}" }.to_sentence
      else
        nil
      end
    rescue JSON::ParserError
      nil
    end
end
