require "net/http"

class Feedback::GithubIssue
  Error = Class.new(StandardError)

  API = "https://api.github.com"
  UPLOADS = "https://uploads.github.com"

  def number_titled(marker, since:)
    issues = get(API, "/repos/#{repository}/issues", state: "all", since: since.iso8601, per_page: 100)
    issues.find { it["title"].include?(marker) }&.fetch("number")
  end

  # WHY: the attachment upload `gh` uses; it is missing from GitHub's REST reference, and on 2026-11-05 it accepted the fine-grained token.
  def upload(blob)
    query = { name: blob.filename.to_s, content_type: blob.content_type, repository_id: repository_id }
    post(UPLOADS, "/user-attachments/assets", blob.download, blob.content_type, query).fetch("url")
  end

  def create(title:, body:)
    post(API, "/repos/#{repository}/issues", { title:, body: }.to_json, "application/json").fetch("number")
  end

  private
    def repository_id
      @repository_id ||= get(API, "/repos/#{repository}").fetch("id")
    end

    def get(base, path, query = {})
      perform Net::HTTP::Get.new(uri(base, path, query))
    end

    def post(base, path, body, content_type, query = {})
      request = Net::HTTP::Post.new(uri(base, path, query))
      request.body = body
      request.content_type = content_type
      perform request
    end

    def uri(base, path, query)
      URI(base + path).tap { it.query = query.to_query if query.any? }
    end

    def perform(request)
      request["Authorization"] = "Bearer #{token}"
      request["Accept"] = "application/vnd.github+json"
      request["X-GitHub-Api-Version"] = "2022-11-28"

      response = Net::HTTP.start(request.uri.host, request.uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { it.request(request) }

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        raise Error, "GitHub answered #{response.code} to #{request.method} #{request.uri.path}"
      end
    end

    def repository
      Rails.application.credentials.dig(:github, :feedback_repository)
    end

    def token
      Rails.application.credentials.dig(:github, :feedback_token)
    end
end
