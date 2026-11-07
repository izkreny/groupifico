# ## Schema Information
#
# Table name: `feedbacks`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`context`**       | `json`             | `not null`
# **`description`**   | `text(20000)`      | `not null`
# **`issue_number`**  | `integer`          |
# **`created_at`**    | `datetime`         | `not null`
# **`updated_at`**    | `datetime`         | `not null`
# **`user_id`**       | `integer`          | `not null`
#
# ### Indexes
#
# * `index_feedbacks_on_user_id`:
#     * **`user_id`**
#
# ### Foreign Keys
#
# * `user_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`user_id => users.id`**
#
class Feedback < ApplicationRecord
  SCREENSHOT_TYPES = %w[ image/png image/jpeg image/gif image/webp ]
  SCREENSHOT_LIMIT = 3
  SCREENSHOT_MAX_SIZE = 5.megabytes
  RETENTION = 66.days

  belongs_to :user
  has_many_attached :screenshots

  # WHY: after `has_many_attached`, because commit callbacks run in the order defined and the screenshots must be uploaded before the filing job can read them.
  include Filing

  # WHY: unfiled feedback exists nowhere but here, so only feedback that became an issue ever expires.
  scope :expired, -> { where.not(issue_number: nil).where(created_at: ...RETENTION.ago) }

  store_accessor :context, :page, :user_agent, :revision,
    :viewport_width, :viewport_height, :screen_width, :screen_height, :pixel_ratio,
    :orientation, :color_scheme, :reduced_motion, :pointer, :display_mode,
    :time_zone, :language, :connection

  validates :description, presence: true, length: { maximum: 5_000 }
  validates :page, length: { maximum: 2_000 }
  validates :user_agent, length: { maximum: 1_000 }
  validates :revision, length: { maximum: 100 }
  validates :viewport_width, :viewport_height, :screen_width, :screen_height,
    numericality: { only_integer: true, in: 1..20_000 }, allow_blank: true
  validates :pixel_ratio, numericality: { in: 0.1..10 }, allow_blank: true
  validates :orientation, inclusion: { in: %w[ portrait-primary portrait-secondary landscape-primary landscape-secondary ] }, allow_blank: true
  validates :color_scheme, inclusion: { in: %w[ light dark ] }, allow_blank: true
  validates :reduced_motion, inclusion: { in: %w[ reduce no-preference ] }, allow_blank: true
  validates :pointer, inclusion: { in: %w[ coarse fine none ] }, allow_blank: true
  validates :display_mode, inclusion: { in: %w[ standalone browser ] }, allow_blank: true
  validates :time_zone, format: { with: %r{\A[A-Za-z0-9_+\-/]{1,64}\z} }, allow_blank: true
  validates :language, format: { with: /\A[A-Za-z0-9-]{2,35}\z/ }, allow_blank: true
  validates :connection, inclusion: { in: %w[ slow-2g 2g 3g 4g ] }, allow_blank: true
  validate :screenshots_are_allowed_images

  # WHY: the issue keeps the report, so the row and its screenshots, which are personal data, go once the retention has passed.
  def self.prune
    expired.with_attached_screenshots.find_each(&:destroy)
  end

  # WHY: `normalizes` never runs on a `store_accessor` key, which is no attribute of its own; the path alone keeps a sign-in link's token out of the issue.
  # WHY: a path opening with two slashes is a link to another site, and the thank-you page links back to this one.
  def page=(url)
    path = URI.parse(url.to_s).path
    super(path.match?(%r{\A/(?![/\\])}) ? path : nil)
  rescue URI::InvalidURIError
    super(nil)
  end

  # The controller that drew the recorded page, so the thank-you page can stand in its section.
  def page_controller
    page_route[:controller]
  end

  def page_group_id
    page_route[:group_id] || (page_route[:id] if page_controller == "groups")
  end

  private
    # WHY: only the router can tell which group and section a path belongs to, and a path it does not know answers with neither.
    def page_route
      @page_route ||= page ? Rails.application.routes.recognize_path(page) : {}
    rescue ActionController::RoutingError
      @page_route = {}
    end

    def screenshots_are_allowed_images
      errors.add(:base, "You can add at most #{SCREENSHOT_LIMIT} screenshots.") if screenshots.size > SCREENSHOT_LIMIT

      new_screenshots.each do |file|
        if file.respond_to?(:original_filename)
          screenshot_is_allowed_image(file)
        else
          errors.add(:base, "A screenshot has to be picked from your device.")
        end
      end
    end

    def screenshot_is_allowed_image(file)
      case sniff(file)
      when *SCREENSHOT_TYPES
        errors.add(:base, "#{file.original_filename} is larger than 5 MB, the most a screenshot can be.") if file.size > SCREENSHOT_MAX_SIZE
      when "image/heic", "image/heif"
        errors.add(:base, "#{file.original_filename} is a HEIC photo, which can't be sent. Take a screenshot instead.")
      else
        errors.add(:base, "#{file.original_filename} isn't a PNG, JPEG, GIF or WebP image.")
      end
    end

    # WHY: a signed blob id is accepted by the attachment setter too, and it names a file whose content was never sniffed or sized here.
    def new_screenshots
      Array(attachment_changes["screenshots"]&.attachables)
    end

    # WHY: Active Storage trusts the declared type whenever the bytes alone match nothing, so a text file declared `image/png` would pass as a PNG.
    def sniff(file)
      Marcel::MimeType.for(file.tempfile).tap { file.tempfile.rewind }
    end
end
