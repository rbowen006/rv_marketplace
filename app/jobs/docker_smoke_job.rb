class DockerSmokeJob < ApplicationJob
  queue_as :default

  def perform(message = "hello from sidekiq")
    Rails.logger.info("[DockerSmokeJob] #{message}")
  end
end
