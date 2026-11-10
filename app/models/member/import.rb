require "csv"

# A member list brought over from a spreadsheet, added to one group the way the "Add member" form adds each person. Nobody is mailed: the welcome mail is `MembersController#create`'s to send, not the model's.
class Member::Import
  HEADERS = %w[ first_name last_name email mobile_phone ].freeze

  class HeaderMismatch < StandardError; end

  Row = Data.define(:line, :outcome, :reasons)

  attr_reader :rows

  def initialize(group, csv)
    @group = group
    @table = CSV.parse(csv, headers: true, strip: true)

    if @table.headers.sort != HEADERS.sort
      raise HeaderMismatch, "Expected the headers #{HEADERS.join(", ")}; got #{@table.headers.join(", ")}"
    end
  end

  # WHY: one refused row rolls every row back, so a file is either imported whole or fixed and run again, and a second run of a whole import finds everybody already in the group.
  def save
    Member.transaction do
      @rows = @table.each.with_index(2).map { |row, line| import(row, line) }
      raise ActiveRecord::Rollback if refused?
    end

    !refused?
  end

  private
    def refused?
      @rows.any? { it.outcome == :refused }
    end

    def import(row, line)
      member  = Member.new(group: @group, email: row["email"])
      user    = member.user
      profile = user.profile || user.build_profile

      if user.persisted? && @group.members.exists?(user:)
        Row.new(line:, outcome: :already_member, reasons: [])
      else
        new_user = user.new_record?
        fill_blanks(profile, row)

        if profile.valid? && member.save && profile.save
          Row.new(line:, outcome: new_user ? :added : :joined, reasons: [])
        else
          Row.new(line:, outcome: :refused, reasons: member.errors.full_messages + profile.errors.full_messages)
        end
      end
    end

    def fill_blanks(profile, row)
      %w[ first_name last_name mobile_phone ].each do |attribute|
        profile[attribute] = row[attribute] if profile[attribute].blank?
      end
    end
end
