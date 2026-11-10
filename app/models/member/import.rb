require "csv"

# A member list brought over from a spreadsheet, added to one group the way the "Add member" form adds each person. Nobody is mailed: the welcome mail is `MembersController#create`'s to send, not the model's.
class Member::Import
  HEADERS = %w[ first_name last_name email mobile_phone ].freeze

  class HeaderMismatch < StandardError; end

  Row = Data.define(:line, :outcome, :reasons)

  attr_reader :rows

  def initialize(group, csv)
    @group = group
    @rows  = []
    # WHY: Excel's "CSV UTF-8" export opens with a byte-order mark, which would otherwise become part of the first header.
    reader  = CSV.new(csv.delete_prefix("\uFEFF"), headers: true, strip: true, return_headers: true)
    headers = Array(reader.shift&.headers)

    if headers.sort != HEADERS.sort
      raise HeaderMismatch, "Expected the headers #{HEADERS.join(", ")}; got #{headers.join(", ")}"
    end

    @records = read_records(reader)
  end

  # WHY: one refused row rolls every row back, so a file is either imported whole or fixed and run again, and a second run of a whole import finds everybody already in the group.
  def save
    Member.transaction do
      @rows = @records.map { |line, record| import(record, line) }
      raise ActiveRecord::Rollback if refused?
    end

    !refused?
  end

  private
    # WHY: `CSV#lineno` counts records rather than lines, so a quoted cell spanning lines would shift every later row's line; each record's own text says how many lines it took.
    def read_records(reader)
      line = 2

      reader.map do |record|
        [ line, record ].tap { line += reader.line.count("\n") }
      end
    end

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
