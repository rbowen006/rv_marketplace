class JsendFailureApp < Devise::FailureApp
  def http_auth_body
    return super unless request_format == :json

    { status: "fail", message: i18n_message }.to_json
  end
end
