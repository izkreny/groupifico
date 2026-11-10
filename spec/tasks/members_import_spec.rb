require "rails_helper"
require "rake"

RSpec.describe "members:import", type: :task do
  let(:group) { create(:group, name: "Zbor") }

  before { Rails.application.load_tasks unless Rake::Task.task_defined?("members:import") }

  def run_task(group_id, input)
    allow($stdin).to receive(:read).and_return(input)

    task = Rake::Task["members:import"]
    task.reenable
    task.invoke(group_id.to_s)
  end

  it "adds every row read from standard input to the group as an active member" do
    expect { run_task(group.id, "first_name,last_name,email,mobile_phone\nAna,Horvat,ana@example.com,+385911111111") }
      .to output("line 2: added\nImported into Zbor.\n").to_stdout

    expect(group.members.find_by!(user: User.find_by!(email: "ana@example.com"))).to be_active
  end

  it "prints one line per row, naming what happened to it" do
    create(:member, group:, user: create(:user, email: "iva@example.com"))
    create(:user, email: "marko@example.com")
    rows = [
      "first_name,last_name,email,mobile_phone",
      "Ana,Horvat,ana@example.com,+385911111111",
      "Marko,Babić,marko@example.com,+385922222222",
      "Iva,Kovač,iva@example.com,+385933333333"
    ].join("\n")

    expect { run_task(group.id, rows) }
      .to output("line 2: added\nline 3: joined\nline 4: already a member\nImported into Zbor.\n").to_stdout
  end

  it "prints a refused row with its reason and aborts, having written nothing" do
    rows = "first_name,last_name,email,mobile_phone\nAna,Horvat,ana@example.com,+385911111111\nMarko,Babić,not-an-address,+385922222222"

    expect {
      expect { expect { run_task(group.id, rows) }.to raise_error(SystemExit) }
        .to output("line 2: added\nline 3: refused: User email is invalid\n").to_stdout
    }.to output("Nothing was imported: fix the refused rows and run it again.\n").to_stderr
    expect(group.members).to be_empty
  end

  it "aborts on an unknown group id before reading any row" do
    expect { expect { run_task(0, "") }.to raise_error(SystemExit) }.to output("No group with id \"0\".\n").to_stderr
    expect($stdin).not_to have_received(:read)
  end

  it "aborts on a header row it does not expect before reading any row" do
    expect { expect { run_task(group.id, "name,email\nAna Horvat,ana@example.com") }.to raise_error(SystemExit) }
      .to output("Expected the headers first_name, last_name, email, mobile_phone; got name, email\n").to_stderr
    expect(group.members).to be_empty
  end
end
