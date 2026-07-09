module AuthenticationHelper
  def sign_in_as(user)
    session = user.sessions.create!
    allow(Current).to receive_messages(user:, session:)
  end

  def sign_out
    Current.session&.destroy!
    allow(Current).to receive(:session).and_return(nil)
  end
end
