require "rails_helper"

RSpec.describe Member::Import do
  let(:group) { create(:group) }

  def csv(*rows)
    [ "first_name,last_name,email,mobile_phone", *rows ].join("\n")
  end

  describe "a row whose address no account holds" do
    it "adds a new user to the group as an active member, with the row's profile" do
      import = described_class.new(group, csv("Ana,Horvat,ana@example.com,+385911111111"))

      expect(import.save).to be(true)

      user = User.find_by!(email: "ana@example.com")
      expect(group.members.find_by!(user:)).to be_active
      expect(user.profile).to have_attributes(first_name: "Ana", last_name: "Horvat", mobile_phone: "+385911111111")
    end

    it "reports the row as added, by its line number" do
      import = described_class.new(group, csv("Ana,Horvat,ana@example.com,+385911111111"))
      import.save

      expect(import.rows).to contain_exactly(have_attributes(line: 2, outcome: :added, reasons: []))
    end
  end

  describe "a row whose address belongs to an account outside the group" do
    let!(:user) { create(:user, email: "marko@example.com") }
    let(:import) { described_class.new(group, csv("Marko,Babić,marko@example.com,+385922222222")) }

    before { user.profile.update!(first_name: "Mark") }

    it "adds that account to the group" do
      expect { import.save }.not_to change(User, :count)

      expect(group.members.find_by!(user:)).to be_active
    end

    it "fills the profile's blank fields and keeps its filled ones" do
      import.save

      expect(user.profile.reload).to have_attributes(first_name: "Mark", last_name: "Babić", mobile_phone: "+385922222222")
    end

    it "reports the row as joined" do
      import.save

      expect(import.rows).to contain_exactly(have_attributes(line: 2, outcome: :joined))
    end
  end

  describe "a row whose address already belongs to a member of the group" do
    it "changes nothing" do
      member = create(:member, group:, user: create(:user, email: "iva@example.com"))
      import = described_class.new(group, csv("Iva,Kovač,iva@example.com,+385933333333"))

      expect { import.save }.not_to change(Member, :count)

      expect(member.profile.reload).to have_attributes(first_name: nil, last_name: nil, mobile_phone: nil)
    end

    it "reports the row as already a member" do
      create(:member, group:, user: create(:user, email: "iva@example.com"))
      import = described_class.new(group, csv("Iva,Kovač,iva@example.com,+385933333333"))
      import.save

      expect(import.rows).to contain_exactly(have_attributes(line: 2, outcome: :already_member))
    end
  end

  it "adds nobody twice when the same file runs twice" do
    rows = csv("Ana,Horvat,ana@example.com,+385911111111", "Marko,Babić,marko@example.com,+385922222222")
    described_class.new(group, rows).save
    second_run = described_class.new(group, rows)

    expect { expect(second_run.save).to be(true) }.not_to change(Member, :count)
    expect(second_run.rows.map(&:outcome)).to eq([ :already_member, :already_member ])
  end

  describe "a file with a refused row" do
    it "writes nothing at all, the valid rows included" do
      import = described_class.new(group, csv("Ana,Horvat,ana@example.com,+385911111111", "Marko,Babić,not-an-address,+385922222222", "Iva,Kovač,iva@example.com,+385944444444"))

      expect { expect(import.save).to be(false) }.not_to change { [ User.count, Member.count, UserProfile.count ] }
    end

    it "reports the refused row with its reason and every other row as it would have gone" do
      import = described_class.new(group, csv("Ana,Horvat,ana@example.com,+385911111111", "Marko,Babić,not-an-address,+385922222222", "Iva,Kovač,iva@example.com,+385944444444"))
      import.save

      expect(import.rows).to contain_exactly(
        have_attributes(line: 2, outcome: :added),
        have_attributes(line: 3, outcome: :refused, reasons: [ "User email is invalid" ]),
        have_attributes(line: 4, outcome: :added)
      )
    end
  end

  it "refuses a row whose mobile number another user already holds" do
    create(:user_profile, mobile_phone: "+385955555555")
    import = described_class.new(group, csv("Ana,Horvat,ana@example.com,+385955555555"))

    expect { import.save }.not_to change(User, :count)
    expect(import.rows).to contain_exactly(have_attributes(line: 2, outcome: :refused, reasons: [ "Mobile phone has already been taken" ]))
  end

  it "refuses a header row other than first_name, last_name, email and mobile_phone before reading any row" do
    expect { described_class.new(group, "name,email\nAna Horvat,ana@example.com") }
      .to raise_error(Member::Import::HeaderMismatch, "Expected the headers first_name, last_name, email, mobile_phone; got name, email")
  end

  it "names each row by the line it starts on when a quoted cell spans two lines" do
    import = described_class.new(group, csv(%("Ana\nMarija",Horvat,ana@example.com,+385911111111), "Marko,Babić,not-an-address,+385922222222"))
    import.save

    expect(import.rows).to contain_exactly(have_attributes(line: 2, outcome: :added), have_attributes(line: 4, outcome: :refused))
  end

  it "lists no rows before it is saved" do
    expect(described_class.new(group, csv("Ana,Horvat,ana@example.com,+385911111111")).rows).to eq([])
  end

  it "reads a file that opens with a byte-order mark, as Excel's UTF-8 CSV export writes one" do
    import = described_class.new(group, "\uFEFF#{csv("Ana,Horvat,ana@example.com,+385911111111")}")

    expect(import.save).to be(true)
  end

  it "sends no mail" do
    expect { described_class.new(group, csv("Ana,Horvat,ana@example.com,+385911111111")).save }.not_to have_enqueued_mail
  end
end
