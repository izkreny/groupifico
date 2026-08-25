module AuthenticationHelper
  def sign_in_as(user)
    post session_path, params: { email: user.email, password: user.password }

    expect(response).to redirect_to root_path
  end
end
