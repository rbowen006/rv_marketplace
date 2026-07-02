# warden-jwt_auth 0.12.0's TokenRevoker only rescues JWT::ExpiredSignature
# when revoking a token on sign-out, not the broader JWT::DecodeError (e.g.
# JWT::Base64DecodeError from a structurally malformed token) — so a garbage
# Authorization header crashes the whole request with a 500, even though the
# controller action already succeeded. The gem exposes no config hook to
# swap TokenRevoker, so this is patched directly. See GitHub issue #8.
module Warden
  module JWTAuth
    module RescuesMalformedTokensOnRevoke
      def call(token)
        super
      rescue JWT::DecodeError
        nil
      end
    end
  end
end

Warden::JWTAuth::TokenRevoker.prepend(Warden::JWTAuth::RescuesMalformedTokensOnRevoke)
