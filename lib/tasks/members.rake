namespace :members do
  desc %(Add the members in a CSV on standard input to a group, mailing nobody; in production: kamal app exec --interactive --reuse "bin/rails 'members:import[<group id>]'" < members.csv)
  task :import, [ :group_id ] => :environment do |_task, args|
    group = Group.find_by(id: args[:group_id])
    abort "No group with id #{args[:group_id].inspect}." unless group

    import = Member::Import.new(group, $stdin.read)
    saved  = import.save

    import.rows.each do |row|
      case row.outcome
      when :added          then puts "line #{row.line}: added"
      when :joined         then puts "line #{row.line}: joined"
      when :already_member then puts "line #{row.line}: already a member"
      when :refused        then puts "line #{row.line}: refused: #{row.reasons.join(", ")}"
      end
    end

    if saved
      puts "Imported into #{group.name}."
    else
      abort "Nothing was imported: fix the refused rows and run it again."
    end
  rescue Member::Import::HeaderMismatch => error
    abort error.message
  end
end
