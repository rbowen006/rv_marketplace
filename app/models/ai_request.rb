class AiRequest < ApplicationRecord
  belongs_to :user, optional: true
end
