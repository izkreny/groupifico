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
# **`description`**   | `text`             | `not null`
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

  belongs_to :user
  has_many_attached :screenshots

  store_accessor :context, :page, :user_agent, :revision,
    :viewport_width, :viewport_height, :screen_width, :screen_height, :pixel_ratio,
    :orientation, :color_scheme, :reduced_motion, :pointer, :display_mode,
    :time_zone, :language, :connection

  validates :description, presence: true, length: { maximum: 5_000 }
  validates :page, format: { with: %r{\A/} }, length: { maximum: 2_000 }, allow_blank: true
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

  # WHY: `normalizes` never runs on a `store_accessor` key, which is no attribute of its own; the path alone keeps a sign-in link's token out of the issue.
  def page=(url)
    super(URI.parse(url.to_s).path.presence)
  rescue URI::InvalidURIError
    super(nil)
  end

  private
    def screenshots_are_allowed_images
      errors.add(:base, "You can add at most #{SCREENSHOT_LIMIT} screenshots.") if screenshots.size > SCREENSHOT_LIMIT

      new_screenshot_files.each do |file|
        case sniff(file)
        when *SCREENSHOT_TYPES
          errors.add(:base, "#{file.original_filename} is larger than 5 MB, the most a screenshot can be.") if file.size > SCREENSHOT_MAX_SIZE
        when "image/heic", "image/heif"
          errors.add(:base, "#{file.original_filename} is a HEIC photo, which can't be sent. Take a screenshot instead.")
        else
          errors.add(:base, "#{file.original_filename} isn't a PNG, JPEG, GIF or WebP image.")
        end
      end
    end

    def new_screenshot_files
      Array(attachment_changes["screenshots"]&.attachables).select { it.respond_to?(:original_filename) }
    end

    # WHY: Active Storage trusts the declared type whenever the bytes alone match nothing, so a text file declared `image/png` would pass as a PNG.
    def sniff(file)
      Marcel::MimeType.for(file.tempfile).tap { file.tempfile.rewind }
    end
end
