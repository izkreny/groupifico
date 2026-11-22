require "rails_helper"

RSpec.describe Member::StatusChange, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:member) }
    it { is_expected.to belong_to(:updater).class_name("Member").required }
  end

  describe "(enums)" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 3, active: 0, paused: 1, inactive: 2).validating }
  end

  describe "a removed updater" do
    it "keeps the changes they made for others, with no member recorded as making them (#126 AC11)" do
      updater = create(:member, :active)
      member  = create(:member, :active, group: updater.group)
      change  = described_class.create!(member:, status: :paused, starts_on: Date.new(2026, 11, 2), updater:)

      updater.destroy!

      expect(change.reload).to have_attributes(status: "paused", starts_on: Date.new(2026, 11, 2), updater_id: nil)
    end
  end
end
