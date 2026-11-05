module Feedback::Filing
  extend ActiveSupport::Concern

  included do
    after_create_commit :file_issue_later, if: -> { Rails.configuration.x.file_feedback }
  end

  def file_issue
    return if issue_number

    github = Feedback::GithubIssue.new
    # WHY: an earlier attempt may have timed out after GitHub had already opened the issue, so its marker is looked for before opening another.
    number = github.number_titled(issue_title, since: created_at) || github.create(title: issue_title, body: issue_body(github))
    update!(issue_number: number)
  end

  private
    def file_issue_later
      Feedback::FileIssueJob.perform_later(self)
    end

    def issue_title
      "[F#{id}]"
    end

    def issue_body(github)
      screenshot_images = screenshots.blobs.map.with_index(1) { |blob, n| "![Screenshot #{n}](#{github.upload(blob)})" }

      [ description, *screenshot_images, context_list ].join("\n\n")
    end

    def context_list
      {
        "Page" => page,
        "User" => user_id,
        "Sent at" => created_at.iso8601,
        "Revision" => revision,
        "User agent" => user_agent,
        "Viewport" => dimensions(viewport_width, viewport_height),
        "Screen" => dimensions(screen_width, screen_height),
        "Pixel ratio" => pixel_ratio,
        "Orientation" => orientation,
        "Colour scheme" => color_scheme,
        "Reduced motion" => reduced_motion,
        "Pointer" => pointer,
        "Display mode" => display_mode,
        "Time zone" => time_zone,
        "Language" => language,
        "Connection" => connection
      }.filter_map { |label, value| "- #{label}: #{value}" if value.present? }.join("\n")
    end

    def dimensions(width, height)
      "#{width} × #{height}" if width.present? && height.present?
    end
end
